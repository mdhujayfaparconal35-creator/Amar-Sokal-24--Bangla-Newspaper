import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'util.dart';
import 'widgets.dart';
import 'screens/category_screen.dart';

/// অ্যাডমিনের আইকন নাম => অ্যাপের আইকন (অ্যাপে আগে থেকে থাকা আইকনের তালিকা)
IconData iconFor(String name) {
  switch (name) {
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

/// হেডারের শিরোনাম: অ্যাপের নাম / লোগো / লোগো + নাম
class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final logoUrl = (dark && s.logo.darkUrl.isNotEmpty) ? s.logo.darkUrl : s.logo.url;
    final showLogo = (s.header.style == 'logo' || s.header.style == 'logo_title') && logoUrl.isNotEmpty;
    final showName = s.header.style != 'logo' || !showLogo;
    final name = Text(s.appName, style: const TextStyle(fontWeight: FontWeight.bold));
    if (!showLogo) return name;
    final logo = NetImage(logoUrl, height: s.logo.height, fit: BoxFit.contain);
    if (!showName) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [logo, const SizedBox(width: 8), Flexible(child: name)],
    );
  }
}

/// সাইড মেনু (অ্যাডমিনের "সাইড মেনু" থেকে)
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

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;
    final primary = Theme.of(context).colorScheme.primary;
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: primary,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 24, 16, 20),
          child: Text(s.appName, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
        ),
        for (final m in s.menu)
          ListTile(
            title: Text(m.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, m),
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
