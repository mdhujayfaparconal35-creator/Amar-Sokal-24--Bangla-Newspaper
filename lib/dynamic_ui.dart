import 'dart:async';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'config.dart';
import 'models.dart';
import 'rewards/reward_api.dart';
import 'rewards/reward_screens.dart';
import 'util.dart';
import 'widgets.dart';
import 'screens/category_screen.dart';
import 'screens/search_screen.dart';

/// অ্যাডমিনের আইকন নাম => অ্যাপের আইকন (অ্যাপে আগে থেকে থাকা আইকনের তালিকা)
IconData iconFor(String name) {
  switch (name) {
    case 'bolt':
      return Icons.flash_on_outlined;
    case 'story':
      return Icons.movie_filter_outlined;
    case 'bell':
      return Icons.notifications_none;
    case 'play':
      return Icons.play_circle_outline;
    case 'search':
      return Icons.search;
    case 'news':
      return Icons.article_outlined;
    case 'tv':
      return Icons.live_tv;
    case 'paper':
      return Icons.newspaper;
    case 'menu':
      return Icons.menu;
    case 'star':
      return Icons.star_outline;
    case 'info':
      return Icons.info_outline;
    case 'grid':
      return Icons.grid_view;
    default:
      return Icons.home_outlined;
  }
}

/// হেডারের লোগোর উচ্চতা ও হেডার বারের উচ্চতা (বড় লোগোর জন্য)
const double kLogoHeight = 54;
const double kBarHeight = 68;

class _LogoCrop {
  final ui.Image image;
  final Rect src;
  const _LogoCrop(this.image, this.src);
}

final Map<String, _LogoCrop?> _logoDone = {};
final Map<String, Future<_LogoCrop?>> _logoLoading = {};

/// লোগোর বামে-ডানে ফাঁকা (স্বচ্ছ/সাদা) অংশ মেপে বাদ দেয়, যাতে লোগো একদম বাম ঘেঁষে বসে
Future<_LogoCrop?> _loadLogoCrop(ImageProvider provider) async {
  try {
    final done = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      if (!done.isCompleted) done.complete(info.image.clone());
      stream.removeListener(l);
    }, onError: (e, _) {
      if (!done.isCompleted) done.completeError(e);
      stream.removeListener(l);
    });
    stream.addListener(l);
    final img = await done.future.timeout(const Duration(seconds: 20));
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return null;
    final w = img.width, h = img.height;
    var minX = w, maxX = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        final r = bd.getUint8(o), g = bd.getUint8(o + 1), b = bd.getUint8(o + 2), a = bd.getUint8(o + 3);
        final blank = a < 16 || (r > 245 && g > 245 && b > 245);
        if (!blank) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
        }
      }
    }
    if (maxX < minX || (maxX - minX) < w * 0.1) return _LogoCrop(img, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    final l0 = (minX - 1).clamp(0, w - 1);
    final r0 = (maxX + 2).clamp(1, w);
    return _LogoCrop(img, Rect.fromLTRB(l0.toDouble(), 0, r0.toDouble(), h.toDouble()));
  } catch (_) {
    return null;
  }
}

class _CropPainter extends CustomPainter {
  final _LogoCrop c;
  const _CropPainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(c.image, c.src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.c != c;
}

/// হেডারের লোগো: ফাঁকা জায়গা কেটে বাম ঘেঁষে দেখায় (না পারলে সাধারণ লোগো)
class HeaderLogo extends StatefulWidget {
  final double height;
  const HeaderLogo({super.key, required this.height});

  @override
  State<HeaderLogo> createState() => _HeaderLogoState();
}

class _HeaderLogoState extends State<HeaderLogo> {
  String _key = '';

  ImageProvider _provider(String url) =>
      url.isNotEmpty ? CachedNetworkImageProvider(url) as ImageProvider : const AssetImage('assets/logo.png');

  void _start(String key, ImageProvider p) {
    if (_logoDone.containsKey(key) || _logoLoading.containsKey(key)) return;
    _logoLoading[key] = _loadLogoCrop(p).then((v) {
      _logoDone[key] = v;
      _logoLoading.remove(key);
      if (mounted) setState(() {});
      return v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = (dark && s.logo.darkUrl.isNotEmpty) ? s.logo.darkUrl : s.logo.url;
    _key = url.isEmpty ? 'asset' : url;
    _start(_key, _provider(url));
    if (!_logoDone.containsKey(_key)) return SizedBox(height: widget.height);
    final c = _logoDone[_key];
    if (c == null) return AppLogo(height: widget.height);
    final w = widget.height * c.src.width / c.src.height;
    return SizedBox(width: w, height: widget.height, child: CustomPaint(painter: _CropPainter(c)));
  }
}

/// ঢোকা পেজের (নিউজ, ভিডিও, ওয়েব পেজ) হেডার: লোগো + সার্চ/মেনু + নিচে আইকন ট্যাব বার।
/// ড্রয়ারওয়ালা Scaffold এর ভেতরে ব্যবহার করতে হবে।
AppBar appHeader(BuildContext context, {bool back = false, bool search = true}) {
  final s = AppSettings.current;
  final hasTabs = s.topTabs.visible(s).isNotEmpty;
  return AppBar(
    toolbarHeight: kBarHeight,
    automaticallyImplyLeading: false,
    leadingWidth: back ? 44 : null,
    leading: back
        ? IconButton(
            tooltip: 'পেছনে',
            icon: const Icon(Icons.arrow_back, size: 26),
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null,
    titleSpacing: back ? 0 : 4,
    centerTitle: false,
    scrolledUnderElevation: 0,
    title: const AppTitle(),
    actions: headerActions(search: search),
    bottom: hasTabs ? const TopTabBar() : null,
  );
}

/// হেডারের লোগো (বামে)। অ্যাডমিনের লোগো থাকলে সেটি, না থাকলে অ্যাপের ভেতরের লোগো।
/// অ্যাডমিনে "লোগো + নাম" বাছলে পাশে নামও দেখায়।
class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;
    const logo = HeaderLogo(height: kLogoHeight);
    if (s.header.style != 'logo_title') {
      return const Align(alignment: Alignment.centerLeft, child: logo);
    }
    final name = Text(s.appName, style: const TextStyle(fontWeight: FontWeight.bold));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [logo, const SizedBox(width: 8), Flexible(child: name)],
    );
  }
}

/// সাইড মেনু (হ্যামবার্গার)। অ্যাডমিনের "সাইড মেনু" ফাঁকা থাকলে সব ক্যাটাগরি দেখায়।
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _open(BuildContext context, MenuItemConf m) {
    final s = AppSettings.current;
    final nav = Navigator.of(context);
    nav.pop(); // ড্রয়ার বন্ধ
    switch (m.type) {
      case 'category':
        final id = int.tryParse(m.target) ?? 0;
        if (id > 0) {
          nav.push(MaterialPageRoute(
            builder: (_) => CategoryScreen(category: Category(id: id, name: m.label, slug: '')),
          ));
        }
        break;
      case 'epaper':
        openLink(s.epaper.url);
        break;
      case 'tv':
        openLink(s.liveTv.url);
        break;
      default:
        openLink(m.target);
    }
  }

  void _openCat(BuildContext context, Category c) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => CategoryScreen(category: c)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;
    final primary = Theme.of(context).colorScheme.primary;
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppConfig.brand, Color.lerp(AppConfig.brand, Colors.white, 0.18)!]),
          ),
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 20, 16, 18),
          child: Row(children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 10)]),
              child: ClipOval(child: Image.asset('assets/logo.png', width: 64, height: 64)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(s.appName, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: RewardApi.me,
          builder: (context, me, _) => ListTile(
            leading: Icon(Icons.monetization_on_rounded, color: Colors.amber.shade700),
            title: const Text('রিওয়ার্ড কয়েন', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: me == null ? const Text('খবর পড়ুন, কয়েন জিতুন') : Text('${bn(ri(me['coins']))} কয়েন'),
            trailing: Icon(Icons.chevron_right, color: primary),
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => const RewardScreen()));
            },
          ),
        ),
        const Divider(height: 1),
        if (s.menu.isNotEmpty)
          ...s.menu.map((m) => ListTile(
                title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Icon(Icons.chevron_right, color: primary),
                onTap: () => _open(context, m),
              ))
        else
          FutureBuilder<HomeData>(
            future: Api.home(),
            builder: (context, snap) {
              final cats = snap.data?.categories ?? const <Category>[];
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              return Column(children: [
                for (final c in cats)
                  ListTile(
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.chevron_right, color: primary),
                    onTap: () => _openCat(context, c),
                  ),
              ]);
            },
          ),
      ]),
    );
  }
}

/// মেইনটেন্যান্স মোড: অ্যাডমিন চালু করলে সবাই এটি দেখে
class MaintenanceScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const MaintenanceScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final m = AppSettings.current.maintenance;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.build_circle_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text(m.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(m.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('আবার চেষ্টা করুন')),
          ]),
        ),
      ),
    );
  }
}

/// নতুন APK দরকার হলে (Native ফিচার/Permission বদলালে) অ্যাডমিন "ন্যূনতম Build" দিয়ে এটি চালু করেন
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = AppSettings.current.update;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.system_update, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text(u.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.5)),
            if (u.url.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: () => openLink(u.url), child: const Text('আপডেট করুন')),
            ],
          ]),
        ),
      ),
    );
  }
}

String? _lastPopupShown; // একই চালুতে একই পপআপ দুবার নয়

/// পপআপ দেখানোর নিয়ম (once / daily / always) মেনে দেখায়।
Future<void> maybeShowPopup(BuildContext context) async {
  final p = AppSettings.current.popup;
  if (!p.on || p.id.isEmpty || _lastPopupShown == p.id) return;
  if (p.title.isEmpty && p.image.isEmpty && p.text.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final key = 'popup_seen_${p.id}';
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final seen = prefs.getString(key);
  if (p.frequency == 'once' && seen != null) return;
  if (p.frequency == 'daily' && seen == today) return;
  if (!context.mounted) return;

  _lastPopupShown = p.id;
  await prefs.setString(key, today);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSettings.current.theme.radius)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            if (p.image.isNotEmpty)
              GestureDetector(
                onTap: p.link.isEmpty
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        openLink(p.link);
                      },
                child: NetImage(p.image, width: double.infinity, fit: BoxFit.fitWidth),
              )
            else
              const SizedBox(height: 40, width: double.infinity),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ]),
          if (p.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(p.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            ),
          if (p.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(p.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.45)),
            ),
          if (p.link.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openLink(p.link);
                },
                child: Text(p.button),
              ),
            )
          else
            const SizedBox(height: 12),
        ]),
      ),
    ),
  );
}


/// পেজের পরিচয়-চাবি (নিচের বার ও ওপরের ট্যাব একই পেজ ভাগ করে নেয়)।
/// লিংক/টিভি/ই-পেপার অ্যাপের ভেতরে পেজ নয় (ব্রাউজারে খোলে), তাই null।
String? pageKeyOf(String type, String target) {
  switch (type) {
    case 'home':
    case 'videos':
    case 'search':
    case 'latest':
    case 'notifications':
    case 'story':
    case 'epaper': // লিংক থাকলে ব্রাউজারে খোলে (Shell আগে দেখে), না থাকলে "শীঘ্রই আসছে" পেজ
      return type;
    case 'category':
      return 'category:$target';
    default:
      return null;
  }
}

/// লিংকধর্মী ট্যাবের ঠিকানা (না হলে null)
String? externalUrlOf(AppSettings s, String type, String target) {
  switch (type) {
    case 'tv':
      return s.liveTv.url;
    case 'link':
      return target;
    default:
      return null;
  }
}

/// ওপরের ট্যাব বার আর Shell এর মধ্যে যোগাযোগ
class TabNav {
  static final ValueNotifier<String> current = ValueNotifier<String>('home');
  static void Function(String type, String target)? onSelect;
}

/// হেডারের নিচের আইকন ট্যাব বার (অ্যাডমিন: "লোগো ও ওপরের ট্যাব")
class TopTabBar extends StatelessWidget implements PreferredSizeWidget {
  const TopTabBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(AppSettings.current.topTabs.showLabel ? 66 : 50);

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;
    final conf = s.topTabs;
    final items = conf.visible(s);
    final theme = Theme.of(context);
    final active = conf.active ?? theme.colorScheme.primary;
    final idle = conf.fg ?? theme.colorScheme.onSurface.withAlpha(160);
    return ValueListenableBuilder<String>(
      valueListenable: TabNav.current,
      builder: (context, cur, _) => Container(
        height: preferredSize.height,
        decoration: BoxDecoration(
          color: conf.bg ?? theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        ),
        child: LayoutBuilder(builder: (context, c) {
          final n = items.isEmpty ? 1 : items.length;
          final w = (c.maxWidth / n) >= 56 ? c.maxWidth / n : 64.0;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final it in items) _tab(context, it, w, cur == pageKeyOf(it.type, it.target), active, idle, conf.showLabel),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _tab(BuildContext context, TopTabItem it, double w, bool sel, Color active, Color idle, bool showLabel) {
    final col = sel ? active : idle;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        // নিউজ/ভিডিও/ওয়েব পেজের ভেতর থেকে ট্যাপ করলে আগে মূল পেজে ফেরে, তারপর ট্যাব বদলায়
        Navigator.of(context).popUntil((r) => r.isFirst);
        TabNav.onSelect?.call(it.type, it.target);
      },
      child: SizedBox(
        width: w,
        height: preferredSize.height,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    it.iconUrl.isNotEmpty
                        ? NetImage(it.iconUrl, width: 26, height: 26, fit: BoxFit.contain)
                        : Icon(iconFor(it.icon), size: 26, color: col),
                    if (showLabel)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            it.label,
                            maxLines: 1,
                            style: TextStyle(fontSize: 11, color: col, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              height: 4,
              margin: EdgeInsets.symmetric(horizontal: sel ? 10 : 26),
              decoration: BoxDecoration(
                color: sel ? col : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// কালবেলার মতো গোল ধূসর বাটন (সার্চ, হ্যামবার্গার)
Widget hdrBtn(BuildContext context, IconData icon, String tip, VoidCallback onTap) {
  final fg = AppSettings.current.header.fg ?? Theme.of(context).colorScheme.onSurface;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Material(
      color: fg.withAlpha(24),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(message: tip, child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 24, color: fg))),
      ),
    ),
  );
}

/// হেডারের ডানে সার্চ ও হ্যামবার্গার মেনু বাটন (সবসময় ডানে, কালবেলা স্টাইল)।
/// ড্রয়ারওয়ালা Scaffold এর ভেতরে থাকতে হবে।
List<Widget> headerActions({bool search = true}) => [
      if (search)
        Builder(
          builder: (c) => hdrBtn(c, Icons.search, 'সার্চ', () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const SearchScreen()))),
        ),
      Builder(builder: (c) => hdrBtn(c, Icons.menu, 'মেনু', () => Scaffold.of(c).openDrawer())),
      const SizedBox(width: 8),
    ];

/// "শীঘ্রই আসছে" পেজ (স্টোরি / ই-পেপারে লিংক না থাকলে)
class ComingSoonScreen extends StatelessWidget {
  final bool inShell;
  final String title;
  final String message;
  const ComingSoonScreen({super.key, this.inShell = false, required this.title, this.message = 'শীঘ্রই আসছে'});

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: inShell,
      title: Text(title),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_empty, size: 56, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ]),
      ),
    );
  }
}

/// Shell এর ভেতরের পেজের Scaffold: ওপরের ট্যাব চালু থাকলে হেডারে লোগো + নিচে ট্যাব বার
class ShellScaffold extends StatelessWidget {
  final bool inShell;
  final Widget? title;
  final bool keepTitle;
  final List<Widget>? actions;
  final bool headerSearch;
  final Widget body;
  const ShellScaffold({super.key, required this.inShell, this.title, this.keepTitle = false, this.actions, this.headerSearch = true, required this.body});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: ConfigStore.notifier,
      builder: (context, s, _) {
        // ট্যাব থাকলে ভেতরে ঢুকলেও (ক্যাটাগরি, সার্চ) হেডার আইকনসহ থাকে; ভেতরের পেজে ব্যাক বাটন যোগ হয়
        final top = s.topTabs.visible(s).isNotEmpty;
        final pushed = !inShell;
        return Scaffold(
          drawer: top ? const AppDrawer() : null,
          appBar: AppBar(
            title: (top && !keepTitle) ? const AppTitle() : title,
            centerTitle: top ? false : true,
            automaticallyImplyLeading: !top,
            leadingWidth: top && pushed ? 44 : null,
            leading: top && pushed
                ? IconButton(
                    tooltip: 'পেছনে',
                    icon: const Icon(Icons.arrow_back, size: 26),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
            toolbarHeight: top ? kBarHeight : null,
            titleSpacing: top ? (pushed ? 0 : 4) : null,
            actions: top ? [...?actions, ...headerActions(search: headerSearch)] : actions,
            bottom: top ? const TopTabBar() : null,
          ),
          body: body,
        );
      },
    );
  }
}
