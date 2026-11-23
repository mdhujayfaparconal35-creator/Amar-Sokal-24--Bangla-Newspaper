import 'package:flutter/material.dart';
import '../api.dart';
import '../config.dart';
import '../fake_stats.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../widgets.dart';
import 'category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future = Api.home();

  Future<void> _refresh() async {
    Api.clearCache();
    setState(() => _future = Api.home());
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // কনফিগ বদলালে (নতুন Publish) হোম নিজে থেকে নতুন ডিজাইনে আঁকে
    return ValueListenableBuilder<AppSettings>(
      valueListenable: ConfigStore.notifier,
      builder: (context, s, _) => Scaffold(
        drawer: const AppDrawer(),
        appBar: _appBar(s),
        body: FutureBuilder<HomeData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SkeletonList(count: 6);
            }
            if (snap.hasError || snap.data == null) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('খবর লোড করা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।'),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _refresh, child: const Text('আবার চেষ্টা করুন')),
                ]),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                FakeStats.bumpMany(snap.data!.latest.map((e) => e.id));
                ConfigStore.refresh(); // পুল-টু-রিফ্রেশে ডিজাইনও নতুন আছে কিনা দেখে
                await _refresh();
              },
              child: _content(context, snap.data!),
            );
          },
        ),
      ),
    );
  }

  AppBar _appBar(AppSettings s) {
    return AppBar(
      title: const AppTitle(),
      centerTitle: false,
      automaticallyImplyLeading: false,
      toolbarHeight: kBarHeight,
      titleSpacing: 4,
      bottom: s.topTabs.visible(s).isNotEmpty ? const TopTabBar() : null,
      actions: headerActions(),
    );
  }

  /// অ্যাডমিনের সেটিংসের ক্রম অনুযায়ী সেকশন সাজানো।
  /// "latest" সেকশনগুলো প্রধান খবরের পর থেকে ক্রমে নিউজ নেয় (ওয়েব প্রিভিউর একই নিয়ম)।
  Widget _content(BuildContext context, HomeData d) {
    final children = <Widget>[];
    final items = d.latest;
    var ptr = 0;

    for (final s in AppSettings.current.sections) {
      if (!s.on) continue;
      switch (s.type) {
        case 'chips':
          final cats = mainCats(d.categories);
          if (cats.isEmpty) break;
          children.add(SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              itemCount: cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = cats[i];
                final pc = Theme.of(context).colorScheme.primary;
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryScreen(category: c))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(colors: [pc.withAlpha(34), pc.withAlpha(12)]),
                      border: Border.all(color: pc.withAlpha(75)),
                    ),
                    child: Text(c.name, style: TextStyle(color: pc, fontWeight: FontWeight.w800, fontSize: 14.5)),
                  ),
                );
              },
            ),
          ));
          break;
        case 'hero':
          if (ptr < items.length) {
            children.add(const SizedBox(height: 4));
            if (s.style == 'big') {
              children.add(HeroBelowCard(items[ptr]));
              ptr++;
            } else {
              // প্রধান খবর: ৫টি খবর ৩ সেকেন্ড পরপর স্লাইড হয়
              final slides = items.skip(ptr).take(5).toList();
              children.add(HeroSlider(slides));
              ptr += slides.length;
            }
          }
          break;
        case 'latest':
          final part = items.skip(ptr).take(s.count).toList();
          ptr += s.count;
          if (part.isNotEmpty) {
            if (s.title.isNotEmpty) children.add(SectionTitle(s.title));
            final st = s.style.isEmpty ? AppSettings.current.cards.style : s.style;
            if (st == 'grid') {
              children.add(NewsGrid(part));
              children.add(AdSlot(slot: 'home', index: ptr));
            } else {
              for (var i = 0; i < part.length; i++) {
                children.add(NewsCard(part[i], style: s.style));
                if ((i + 1) % 5 == 0) children.add(AdSlot(slot: 'home', index: ptr + i));
              }
            }
          }
          break;
        case 'videos':
          final v = d.videos.take(s.count).toList();
          if (v.isNotEmpty) {
            children.add(SectionTitle(s.title));
            children.add(SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: v.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => VideoCard(v[i], width: 220),
              ),
            ));
          }
          break;
        case 'category':
          if (s.category > 0) {
            children.add(SectionTitle(s.title.isEmpty ? 'ক্যাটাগরি' : s.title));
            children.add(CategorySection(categoryId: s.category, count: s.count, style: s.style));
          }
          break;
        case 'banner':
          final bs = AppSettings.current.banners.where((b) => b.slot == (s.slot.isEmpty ? 'main' : s.slot)).toList();
          if (bs.isNotEmpty && s.title.isNotEmpty) children.add(SectionTitle(s.title));
          children.addAll(bs.map((b) => PromoImage(b)));
          break;
        case 'ad':
          final ads = AppSettings.current.ads.where((b) => b.slot == (s.slot.isEmpty ? 'main' : s.slot)).toList();
          children.addAll(ads.map((b) => PromoImage(b, isAd: true)));
          break;
        case 'breaking':
          final bc = AppSettings.current.breaking;
          if (!bc.on) break;
          final list = bc.source == 'latest'
              ? d.latest.take(bc.count).map((n) => BreakItem(n.title, n.id)).toList()
              : bc.items.map((t) => BreakItem(t)).toList();
          if (list.isNotEmpty) children.add(BreakingBar(conf: bc, items: list));
          break;
        case 'tv':
          final tv = AppSettings.current.liveTv;
          if (tv.on && tv.url.isNotEmpty) children.add(LinkCard(tv, icon: Icons.live_tv));
          break;
        case 'epaper':
          final ep = AppSettings.current.epaper;
          if (ep.on && ep.url.isNotEmpty) children.add(LinkCard(ep, icon: Icons.newspaper));
          break;
      }
    }
    // মূল ক্যাটাগরির খবর: ক্যাটাগরির নামসহ কয়েকটি করে (অ্যাডমিনের সেকশনে যেগুলো আছে সেগুলো বাদ)
    final usedIds = AppSettings.current.sections.where((x) => x.on && x.type == 'category').map((x) => x.category).toSet();
    for (final c in mainCats(d.categories).take(AppConfig.homeCategoryBlocks)) {
      if (usedIds.contains(c.id)) continue;
      children.add(CategoryHomeBlock(category: c));
    }
    children.add(const SizedBox(height: 24));
    children.add(const AppFooter());

    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: children);
  }
}

/// নির্দিষ্ট ক্যাটাগরির কয়েকটি খবর (হোমের একটি সেকশন)
class CategorySection extends StatelessWidget {
  final int categoryId, count;
  final String style;
  const CategorySection({super.key, required this.categoryId, required this.count, this.style = ''});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NewsItem>>(
      future: Api.posts(category: categoryId, perPage: count),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) return const SizedBox.shrink();
        final st = style.isEmpty ? AppSettings.current.cards.style : style;
        if (st == 'grid') return NewsGrid(list);
        return Column(children: list.map((n) => NewsCard(n, style: style)).toList());
      },
    );
  }
}


/// হোমের ওপরের চিপ ও নিচের সেকশনের জন্য শুধু মূল ক্যাটাগরি (AppConfig.mainCategories এর ক্রমে)
List<Category> mainCats(List<Category> all) {
  final picked = <Category>[];
  for (final n in AppConfig.mainCategories) {
    for (final c in all) {
      if (c.name.trim() == n) {
        picked.add(c);
        break;
      }
    }
  }
  if (picked.length >= 3) return picked;
  final hidden = AppConfig.hiddenCategories.toSet();
  final rest = all.where((c) => !hidden.contains(c.name.trim()) && c.count > 0).toList()..sort((a, b) => b.count.compareTo(a.count));
  return rest.take(6).toList();
}

/// হোমের নিচে: ক্যাটাগরির নাম + "আরও" বাটন + কয়েকটি খবর
class CategoryHomeBlock extends StatelessWidget {
  final Category category;
  const CategoryHomeBlock({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    void openAll() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryScreen(category: category)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 22, 6, 6),
        child: Row(children: [
          Container(
            width: 5,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c, Color.lerp(c, Colors.redAccent, 0.55)!]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(category.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
          TextButton(
            onPressed: openAll,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('আরও খবর', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
              Icon(Icons.chevron_right, color: c, size: 20),
            ]),
          ),
        ]),
      ),
      CategorySection(categoryId: category.id, count: AppConfig.homeCategoryCount),
    ]);
  }
}
