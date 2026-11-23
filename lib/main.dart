import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'api.dart';
import 'config.dart';
import 'dynamic_ui.dart';
import 'models.dart';
import 'fake_stats.dart';
import 'notifications.dart';
import 'rewards/reward_api.dart';
import 'screens/category_screen.dart';
import 'screens/epaper_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
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
  await FakeStats.load();
  await RewardApi.init();
  unawaited(RewardApi.loadConfig());
  runApp(const NewsApp());
  // নোটিফিকেশন: অনুমতি চাওয়া + ব্যাকগ্রাউন্ডে নতুন নিউজ/ভিডিও দেখা (অ্যাপ বন্ধ থাকলেও)
  Notifier.loadHistory();
  Notifier.start().then((_) => Notifier.checkNew());
}

ThemeData _buildTheme(AppSettings s, Brightness b) {
  final t = s.theme;
  final dark = b == Brightness.dark;
  final bg = dark ? t.darkBg : t.lightBg;
  final fg = dark ? t.darkText : t.lightText;
  final card = dark ? t.darkCard : t.lightCard;
  // গাঢ় নীল ব্র্যান্ড রং ডার্ক মোডের কালো ব্যাকগ্রাউন্ডে মিশে যায়, তাই ডার্ক মোডে একটু হালকা করা হয়
  var prim = t.primary;
  if (dark) {
    final hsl = HSLColor.fromColor(prim);
    if (hsl.lightness < 0.55) prim = hsl.withLightness(0.62).toColor();
  }
  final scheme = ColorScheme.fromSeed(seedColor: prim, brightness: b).copyWith(
    primary: prim,
    secondary: t.secondary,
    surface: bg,
    onSurface: fg,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: 'Kalpurush');
  return base.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    scaffoldBackgroundColor: bg,
    cardColor: card,
    canvasColor: bg,
    textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
    appBarTheme: AppBarTheme(
      backgroundColor: s.header.bg ?? bg,
      foregroundColor: s.header.fg ?? fg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 3,
      shadowColor: Colors.black.withAlpha(dark ? 120 : 70),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
    ),
    dividerTheme: DividerThemeData(color: fg.withAlpha(30), space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.nav.bg ?? bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: (s.nav.active ?? prim).withAlpha(40),
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
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // অ্যাপ খোলা থাকলে প্রতি ৩ মিনিটে নতুন নিউজ/ভিডিও দেখে
    _notifTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      Notifier.loadHistory(); // দিন বদলালে নোটিফিকেশনের সংখ্যা ০ থেকে শুরু
      Notifier.checkNew();
    });
    // ক্যাশ দিয়ে চালু হলে পেছনে নতুন version আছে কিনা দেখা
    if (ConfigStore.hasCache) ConfigStore.refresh();
    _timer = Timer.periodic(const Duration(minutes: AppConfig.configRefreshMinutes), (_) => ConfigStore.refreshIfStale());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notifTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ConfigStore.refreshIfStale();
      Notifier.loadHistory();
      Notifier.checkNew();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: ConfigStore.notifier,
      builder: (context, s, _) => MaterialApp(
        title: s.appName,
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavKey,
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
  // বর্তমান পেজের চাবি (pageKeyOf দেখুন); নিচের বার ও ওপরের ট্যাব একই চাবি ভাগ করে
  String _cur = 'home';
  // পেজগুলো প্রথমবার ট্যাপ করলেই লোড হয় (অকারণে সার্ভারে রিকোয়েস্ট যায় না)
  final Map<String, Widget> _pages = {};

  @override
  void initState() {
    super.initState();
    TabNav.onSelect = _select;
    ConfigStore.notifier.addListener(_onConfig);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowPopup(context);
      Notifier.handleLaunch(); // নোটিফিকেশনে ট্যাপ করে অ্যাপ খুললে সেই নিউজ/ভিডিও খোলে
    });
  }

  @override
  void dispose() {
    if (TabNav.onSelect == _select) TabNav.onSelect = null;
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

  /// পেজের চাবি => ট্যাবের নাম (শিরোনামের জন্য)
  Map<String, String> _labels(AppSettings s) {
    final m = <String, String>{};
    for (final i in _items(s)) {
      final k = pageKeyOf(i.type, i.target);
      if (k != null) m.putIfAbsent(k, () => i.label);
    }
    for (final t in s.topTabs.visible(s)) {
      final k = pageKeyOf(t.type, t.target);
      if (k != null) m.putIfAbsent(k, () => t.label);
    }
    return m;
  }

  Widget _buildPage(String key, AppSettings s) {
    final label = _labels(s)[key] ?? '';
    switch (key) {
      case 'videos':
        return const VideosScreen(inShell: true);
      case 'search':
        return const SearchScreen(inShell: true);
      case 'notifications':
        return const NotificationsScreen(inShell: true);
      case 'story':
        return ComingSoonScreen(inShell: true, title: label.isEmpty ? 'রিলস' : label, message: 'রিলস লোড হয়নি।\nশীঘ্রই চালু হবে।');
      case 'epaper':
        return const EpaperScreen(inShell: true);
      case 'latest':
        return CategoryScreen(category: Category(id: 0, name: label.isEmpty ? 'সর্বশেষ' : label, slug: ''), inShell: true);
      default:
        if (key.startsWith('category:')) {
          final id = int.tryParse(key.substring(9)) ?? 0;
          if (id == 0) return ComingSoonScreen(inShell: true, title: label);
          return CategoryScreen(category: Category(id: id, name: label, slug: ''), inShell: true);
        }
        return const HomeScreen();
    }
  }

  /// নিচের বার বা ওপরের ট্যাব — যেখানেই ট্যাপ হোক
  void _select(String type, String target) {
    final s = AppSettings.current;
    final ext = externalUrlOf(s, type, target);
    if (ext != null) {
      openLink(ext);
      return;
    }
    final key = pageKeyOf(type, target);
    if (key == null || !mounted) return;
    setState(() {
      _pages.putIfAbsent(key, () => _buildPage(key, s));
      _cur = key;
    });
    TabNav.current.value = key;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;

    if (s.update.minBuild > AppConfig.build) return const UpdateScreen();
    if (s.maintenance.on) {
      return MaintenanceScreen(onRetry: () => ConfigStore.refresh());
    }

    final bottom = _items(s);
    final tops = s.topTabs.visible(s);

    // সব পেজের চাবি (ডুপ্লিকেট বাদ): নিচের বারের হোম আর ওপরের হোম একই পেজ
    final keys = <String>[];
    for (final i in bottom) {
      final k = pageKeyOf(i.type, i.target);
      if (k != null && !keys.contains(k)) keys.add(k);
    }
    for (final t in tops) {
      final k = pageKeyOf(t.type, t.target);
      if (k != null && !keys.contains(k)) keys.add(k);
    }
    if (keys.isEmpty) keys.add('home');
    if (!keys.contains(_cur)) _cur = keys.first;
    _pages.removeWhere((k, _) => !keys.contains(k));
    _pages.putIfAbsent(_cur, () => _buildPage(_cur, s));
    if (TabNav.current.value != _cur) {
      WidgetsBinding.instance.addPostFrameCallback((_) => TabNav.current.value = _cur);
    }

    const showBar = false; // নিচের হোম/ভিডিও/সার্চ বার সরানো হয়েছে (ওপরের ট্যাব বারই মূল নেভিগেশন)
    final active = s.nav.active;
    // বর্তমান পেজ নিচের বারে না থাকলে (শুধু ওপরের ট্যাবে আছে) নিচে কিছু হাইলাইট হবে না
    final bi = bottom.indexWhere((i) => pageKeyOf(i.type, i.target) == _cur);
    final sel = bi < 0 ? 0 : bi;

    return Scaffold(
      body: IndexedStack(
        index: keys.indexOf(_cur),
        children: [for (final k in keys) _pages[k] ?? const SizedBox.shrink()],
      ),
      bottomNavigationBar: !showBar
          ? null
          : NavigationBar(
              selectedIndex: sel,
              indicatorColor: bi < 0 ? Colors.transparent : null,
              onDestinationSelected: (i) => _select(bottom[i].type, bottom[i].target),
              destinations: [
                for (var n = 0; n < bottom.length; n++)
                  NavigationDestination(
                    icon: Icon(iconFor(bottom[n].icon)),
                    selectedIcon: Icon(iconFor(bottom[n].icon), color: bi < 0 ? null : active),
                    label: bottom[n].label,
                  ),
              ],
            ),
    );
  }
}
