import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'config.dart';
import 'models.dart';
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

/// হেডারের লোগো (বামে)। অ্যাডমিনের লোগো থাকলে সেটি, না থাকলে অ্যাপের ভেতরের লোগো।
/// অ্যাডমিনে "লোগো + নাম" বাছলে পাশে নামও দেখায়।
class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;
    const logo = AppLogo(height: kLogoHeight);
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
            ClipOval(child: Image.asset('assets/logo.png', width: 56, height: 56)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(s.appName, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        if (s.menu.isNotEmpty)
          ...s.menu.map((m) => ListTile(
                title: Text(m.label),
                trailing: const Icon(Icons.chevron_right),
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
                    title: Text(c.name),
                    trailing: const Icon(Icons.chevron_right),
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
          border: Border(bottom: BorderSide(color: theme.dividerColor.withAlpha(90))),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final n = items.isEmpty ? 1 : items.length;
          final w = (c.maxWidth / n) >= 56 ? c.maxWidth / n : 64.0;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final it in items) _tab(it, w, cur == pageKeyOf(it.type, it.target), active, idle, conf.showLabel),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _tab(TopTabItem it, double w, bool sel, Color active, Color idle, bool showLabel) {
    final col = sel ? active : idle;
    return InkWell(
      onTap: () => TabNav.onSelect?.call(it.type, it.target),
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
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 10),
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
        final top = inShell && s.topTabs.visible(s).isNotEmpty;
        return Scaffold(
          drawer: top ? const AppDrawer() : null,
          appBar: AppBar(
            title: (top && !keepTitle) ? const AppTitle() : title,
            centerTitle: top ? false : true,
            automaticallyImplyLeading: !top,
            toolbarHeight: top ? kBarHeight : null,
            titleSpacing: top ? 10 : null,
            actions: top ? [...?actions, ...headerActions(search: headerSearch)] : actions,
            bottom: top ? const TopTabBar() : null,
          ),
          body: body,
        );
      },
    );
  }
}
