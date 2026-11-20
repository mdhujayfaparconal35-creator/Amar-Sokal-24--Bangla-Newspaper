import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'config.dart';
import 'dynamic_ui.dart';
import 'models.dart';
import 'screens/category_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/videos_screen.dart';
import 'util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ১) আগের ক্যাশ করা ডিজাইন সাথে সাথে (ইন্টারনেট না থাকলেও চলে)
  await ConfigStore.loadCached();
  // ২) একদম প্রথমবার (ক্যাশ নেই) হলে সর্বোচ্চ ৩ সেকেন্ড সার্ভারের ডিজাইনের জন্য অপেক্ষা
  if (!ConfigStore.hasCache) {
    await ConfigStore.refresh(timeout: const Duration(seconds: 3));
  }
  runApp(const NewsApp());
}

ThemeData _buildTheme(AppSettings s, Brightness b) {
  final t = s.theme;
  final dark = b == Brightness.dark;
  final bg = dark ? t.darkBg : t.lightBg;
  final fg = dark ? t.darkText : t.lightText;
  final card = dark ? t.darkCard : t.lightCard;
  final scheme = ColorScheme.fromSeed(seedColor: t.primary, brightness: b).copyWith(
    primary: t.primary,
    secondary: t.secondary,
    surface: bg,
    onSurface: fg,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    cardColor: card,
    canvasColor: bg,
    textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
    appBarTheme: AppBarTheme(
      backgroundColor: s.header.bg ?? bg,
      foregroundColor: s.header.fg ?? fg,
      surfaceTintColor: Colors.transparent,
      centerTitle: s.header.centered,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.nav.bg ?? bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: (s.nav.active ?? t.primary).withAlpha(40),
    ),
  );
}

ThemeMode _mode(String m) => m == 'dark' ? ThemeMode.dark : (m == 'light' ? ThemeMode.light : ThemeMode.system);

class NewsApp extends StatefulWidget {
  const NewsApp({super.key});

  @override
  State<NewsApp> createState() => _NewsAppState();
}

class _NewsAppState extends State<NewsApp> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ক্যাশ দিয়ে চালু হলে পেছনে নতুন version আছে কিনা দেখা
    if (ConfigStore.hasCache) ConfigStore.refresh();
    _timer = Timer.periodic(const Duration(minutes: AppConfig.configRefreshMinutes), (_) => ConfigStore.refreshIfStale());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ConfigStore.refreshIfStale();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: ConfigStore.notifier,
      builder: (context, s, _) => MaterialApp(
        title: s.appName,
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(s, Brightness.light),
        darkTheme: _buildTheme(s, Brightness.dark),
        themeMode: _mode(s.theme.mode),
        builder: (context, child) {
          // Font Size: ফোনের নিজস্ব সেটিংয়ের ওপর অ্যাডমিনের গুণক বসে
          final mq = MediaQuery.of(context);
          final sys = mq.textScaler.scale(10) / 10;
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(sys * s.theme.fontScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  // পেজগুলো প্রথমবার ট্যাপ করলেই লোড হয় (অকারণে সার্ভারে রিকোয়েস্ট যায় না)
  final Map<String, Widget> _pages = {};

  @override
  void initState() {
    super.initState();
    ConfigStore.notifier.addListener(_onConfig);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowPopup(context);
    });
  }

  @override
  void dispose() {
    ConfigStore.notifier.removeListener(_onConfig);
    super.dispose();
  }

  void _onConfig() {
    if (!mounted) return;
    setState(() {});
    maybeShowPopup(context);
  }

  List<NavItem> _items(AppSettings s) {
    final list = s.nav.items.where((i) => i.on).toList();
    return list.isEmpty ? NavConf.defaults().items : list;
  }

  Widget _buildPage(NavItem it) {
    switch (it.type) {
      case 'videos':
        return const VideosScreen();
      case 'search':
        return const SearchScreen();
      case 'category':
        return CategoryScreen(category: Category(id: int.tryParse(it.target) ?? 0, name: it.label, slug: ''));
      default:
        return const HomeScreen();
    }
  }

  /// লিংকধর্মী ট্যাব (লাইভ টিভি / ই-পেপার / লিংক) অ্যাপের ভেতরে পেজ নয়, ব্রাউজারে খোলে
  String? _externalUrl(AppSettings s, NavItem it) {
    switch (it.type) {
      case 'tv':
        return s.liveTv.url;
      case 'epaper':
        return s.epaper.url;
      case 'link':
        return it.target;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;

    if (s.update.minBuild > AppConfig.build) return const UpdateScreen();
    if (s.maintenance.on) {
      return MaintenanceScreen(onRetry: () => ConfigStore.refresh());
    }

    final items = _items(s);
    if (_index >= items.length) _index = 0;
    final keys = items.map((i) => i.key).toSet();
    _pages.removeWhere((k, _) => !keys.contains(k));
    final cur = items[_index];
    if (_externalUrl(s, cur) == null) _pages.putIfAbsent(cur.key, () => _buildPage(cur));

    final showBar = s.nav.enabled && items.length > 1;
    final active = s.nav.active;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (final i in items) _pages[i.key] ?? const SizedBox.shrink()],
      ),
      bottomNavigationBar: !showBar
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) {
                final it = items[i];
                final ext = _externalUrl(s, it);
                if (ext != null) {
                  openLink(ext);
                  return;
                }
                setState(() {
                  _pages.putIfAbsent(it.key, () => _buildPage(it));
                  _index = i;
                });
              },
              destinations: [
                for (final i in items)
                  NavigationDestination(
                    icon: Icon(iconFor(i.icon)),
                    selectedIcon: Icon(iconFor(i.icon), color: active),
                    label: i.label,
                  ),
              ],
            ),
    );
  }
}
