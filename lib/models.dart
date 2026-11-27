import 'package:flutter/material.dart' show Color, Colors;
import 'config.dart';

String _s(dynamic v) => v == null ? '' : v.toString();

class Category {
  final int id;
  final String name;
  final String slug;
  final int count;
  Category({required this.id, required this.name, required this.slug, this.count = 0});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: (j['id'] as num).toInt(),
        name: _s(j['name']),
        slug: _s(j['slug']),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class NewsItem {
  final int id;
  final String title, excerpt, image, date, link, reporter;
  final Category? category;
  NewsItem({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.image,
    required this.date,
    required this.link,
    required this.reporter,
    this.category,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) {
    final r = j['reporter'];
    final c = j['category'];
    return NewsItem(
      id: (j['id'] as num).toInt(),
      title: _s(j['title']),
      excerpt: _s(j['excerpt']),
      image: _s(j['image']),
      date: _s(j['date']),
      link: _s(j['link']),
      reporter: r is Map ? _s(r['name']) : _s(r),
      category: c is Map ? Category.fromJson(Map<String, dynamic>.from(c)) : null,
    );
  }
}

class NewsDetail {
  final NewsItem item;
  final String content, reporterName, reporterDesignation, reporterImage;
  final List<NewsItem> related;
  NewsDetail({
    required this.item,
    required this.content,
    required this.reporterName,
    required this.reporterDesignation,
    required this.reporterImage,
    required this.related,
  });

  factory NewsDetail.fromJson(Map<String, dynamic> j) {
    final r = j['reporter'] is Map ? Map<String, dynamic>.from(j['reporter']) : <String, dynamic>{};
    final rel = (j['related'] as List? ?? [])
        .map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return NewsDetail(
      item: NewsItem.fromJson(j),
      content: _s(j['content']),
      reporterName: _s(r['name']),
      reporterDesignation: _s(r['designation']),
      reporterImage: _s(r['image']),
      related: rel,
    );
  }
}

class VideoItem {
  final int id;
  final String title, date, youtube, thumb;
  VideoItem({required this.id, required this.title, required this.date, required this.youtube, required this.thumb});

  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
        id: (j['id'] as num).toInt(),
        title: _s(j['title']),
        date: _s(j['date']),
        youtube: _s(j['youtube']),
        thumb: _s(j['thumb']),
      );
}

class HomeData {
  final List<NewsItem> latest;
  final List<VideoItem> videos;
  final List<Category> categories;
  HomeData({required this.latest, required this.videos, required this.categories});

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        latest: (j['latest'] as List? ?? []).map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        videos: (j['videos'] as List? ?? []).map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        categories: (j['categories'] as List? ?? []).map((e) => Category.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}


// ======================================================================
// অ্যাডমিন প্যানেলের "মোবাইল অ্যাপ" থেকে আসা Remote Configuration (schema 2)
// প্রতিটি ক্লাস ভুল/অনুপস্থিত ডাটা সামলে ডিফল্ট ধরে: সার্ভারের ভুল কনফিগে অ্যাপ ভাঙে না।
// ======================================================================

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _l(dynamic v) => v is List ? v : const [];
bool _b(dynamic v, bool d) => v is bool ? v : d;
int _i(dynamic v, int d) => v is num ? v.toInt() : (int.tryParse(_s(v)) ?? d);
double _d(dynamic v, double d) => v is num ? v.toDouble() : (double.tryParse(_s(v)) ?? d);

/// "#RRGGBB" বা "#RGB" => Color; ভুল হলে null
Color? parseHex(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return null;
  final v = int.tryParse('FF$h', radix: 16);
  return v == null ? null : Color(v);
}

Color _c(dynamic v, Color d) => parseHex(_s(v)) ?? d;
Color? _co(dynamic v) => parseHex(_s(v));

class SectionConf {
  final String type, title, style, slot;
  final int count, category;
  final bool on;
  SectionConf({
    required this.type,
    required this.title,
    required this.count,
    required this.category,
    required this.on,
    this.style = '',
    this.slot = '',
  });

  factory SectionConf.fromJson(Map<String, dynamic> j) => SectionConf(
        type: _s(j['type']),
        title: _s(j['title']),
        count: _i(j['count'], 0),
        category: _i(j['category'], 0),
        on: j['on'] != false,
        style: _s(j['style']),
        slot: _s(j['slot']),
      );
}

class ThemeConf {
  final String mode; // system | light | dark
  final Color primary, secondary, lightBg, lightText, lightCard, darkBg, darkText, darkCard;
  final double fontScale;
  final double radius;
  const ThemeConf({
    required this.mode,
    required this.primary,
    required this.secondary,
    required this.lightBg,
    required this.lightText,
    required this.lightCard,
    required this.darkBg,
    required this.darkText,
    required this.darkCard,
    required this.fontScale,
    required this.radius,
  });

  factory ThemeConf.defaults() => const ThemeConf(
        mode: 'system',
        primary: AppConfig.brand,
        secondary: Color(0xFF1565C0),
        lightBg: Color(0xFFFFFFFF),
        lightText: Color(0xFF111111),
        lightCard: Color(0xFFF3F3F3),
        darkBg: Color(0xFF121212),
        darkText: Color(0xFFEEEEEE),
        darkCard: Color(0xFF222222),
        fontScale: 1.0,
        radius: 10,
      );

  factory ThemeConf.fromJson(Map<String, dynamic> j, Color legacyPrimary) {
    final d = ThemeConf.defaults();
    final mode = _s(j['mode']);
    return ThemeConf(
      mode: const ['system', 'light', 'dark'].contains(mode) ? mode : 'system',
      // পুরনো ডিফল্ট লাল (#D32F2F / #E30713) থাকলে নতুন ব্র্যান্ড রঙ; অন্য রঙ অ্যাডমিন নিজে দিলে সেটাই
      primary: () {
        final c = _c(j['primary'], legacyPrimary);
        final v = c.toARGB32();
        return (v == 0xFFD32F2F || v == 0xFFE30713) ? AppConfig.brand : c;
      }(),
      secondary: _c(j['secondary'], d.secondary),
      lightBg: _c(j['lightBg'], d.lightBg),
      lightText: _c(j['lightText'], d.lightText),
      lightCard: _c(j['lightCard'], d.lightCard),
      darkBg: _c(j['darkBg'], d.darkBg),
      darkText: _c(j['darkText'], d.darkText),
      darkCard: _c(j['darkCard'], d.darkCard),
      fontScale: _d(j['fontScale'], 1.0).clamp(0.8, 1.4).toDouble(),
      radius: _d(j['radius'], 10).clamp(0, 28).toDouble(),
    );
  }
}

class LogoConf {
  final String url, darkUrl;
  final double height;
  const LogoConf({this.url = '', this.darkUrl = '', this.height = 40});

  factory LogoConf.fromJson(Map<String, dynamic> j) => LogoConf(
        url: _s(j['url']),
        darkUrl: _s(j['darkUrl']),
        height: _d(j['height'], 40).clamp(16, 80).toDouble(),
      );
}

class HeaderConf {
  final String style; // title | logo | logo_title
  final String iconStyle; // plain | circle (গোল ধূসর বাটন)
  final String iconSide; // right | left
  final Color? bg, fg;
  final bool centered, search;
  const HeaderConf({
    this.style = 'logo',
    this.iconStyle = 'circle',
    this.iconSide = 'right',
    this.bg,
    this.fg,
    this.centered = false,
    this.search = true,
  });

  factory HeaderConf.fromJson(Map<String, dynamic> j) => HeaderConf(
        style: const ['title', 'logo', 'logo_title'].contains(_s(j['style'])) ? _s(j['style']) : 'logo',
        iconStyle: _s(j['iconStyle']) == 'plain' ? 'plain' : 'circle',
        iconSide: _s(j['iconSide']) == 'left' ? 'left' : 'right',
        bg: _co(j['bg']),
        fg: _co(j['fg']),
        centered: _b(j['centered'], false),
        search: _b(j['search'], true),
      );
}

class NavItem {
  final String id, label, icon, type, target;
  final bool on;
  const NavItem({required this.id, required this.label, required this.icon, required this.type, this.target = '', this.on = true});

  String get key => '$id|$type|$target';

  factory NavItem.fromJson(Map<String, dynamic> j) => NavItem(
        id: _s(j['id']),
        label: _s(j['label']),
        icon: _s(j['icon']),
        type: _s(j['type']),
        target: _s(j['target']),
        on: j['on'] != false,
      );
}

class NavConf {
  final bool enabled;
  final Color? bg, active;
  final List<NavItem> items;
  const NavConf({this.enabled = true, this.bg, this.active, required this.items});

  factory NavConf.defaults() => const NavConf(items: [
        NavItem(id: 'n0', label: 'হোম', icon: 'home', type: 'home'),
        NavItem(id: 'n1', label: 'ভিডিও', icon: 'play', type: 'videos'),
        NavItem(id: 'n2', label: 'সার্চ', icon: 'search', type: 'search'),
      ]);

  factory NavConf.fromJson(Map<String, dynamic> j) {
    final list = _l(j['items']).map((e) => NavItem.fromJson(_m(e))).where((n) => n.type.isNotEmpty).toList();
    return NavConf(
      enabled: _b(j['enabled'], true),
      bg: _co(j['bg']),
      active: _co(j['activeColor']),
      items: list.isEmpty ? NavConf.defaults().items : list,
    );
  }
}

/// ওপরের আইকন ট্যাব বারের একটি আইটেম (অ্যাডমিন: "লোগো ও ওপরের ট্যাব")
class TopTabItem {
  final String id, label, icon, iconUrl, type, target;
  final bool on;
  const TopTabItem({
    required this.id,
    required this.label,
    required this.icon,
    this.iconUrl = '',
    required this.type,
    this.target = '',
    this.on = true,
  });

  factory TopTabItem.fromJson(Map<String, dynamic> j) => TopTabItem(
        id: _s(j['id']),
        label: _s(j['label']),
        icon: _s(j['icon']),
        iconUrl: _s(j['iconUrl']),
        type: _s(j['type']),
        target: _s(j['target']),
        on: j['on'] != false,
      );
}

class TopTabsConf {
  final bool enabled, showLabel;
  final Color? bg, fg, active;
  final List<TopTabItem> items;
  const TopTabsConf({this.enabled = false, this.showLabel = true, this.bg, this.fg, this.active, this.items = const []});

  /// কালবেলা স্টাইলের ৬টি ট্যাব (ইন্টারনেট/কনফিগ না থাকলে এটাই চলে)
  factory TopTabsConf.defaults() => const TopTabsConf(enabled: true, items: [
        TopTabItem(id: 't0', label: 'হোম', icon: 'home', type: 'home'),
        TopTabItem(id: 't2', label: 'ভিডিও', icon: 'play', type: 'videos'),
        TopTabItem(id: 't3', label: 'রিলস', icon: 'story', type: 'story'),
        TopTabItem(id: 't4', label: 'নোটিফিকেশন', icon: 'bell', type: 'notifications'),
        TopTabItem(id: 't5', label: 'ই-পেপার', icon: 'paper', type: 'epaper'),
      ]);

  factory TopTabsConf.fromJson(Map<String, dynamic> j) => TopTabsConf(
        enabled: _b(j['enabled'], false),
        showLabel: _b(j['showLabel'], true),
        bg: _co(j['bg']),
        fg: _co(j['fg']),
        active: _co(j['activeColor']),
        items: _l(j['items']).map((e) => TopTabItem.fromJson(_m(e))).where((t) => t.type.isNotEmpty).toList(),
      );

  /// এখন সত্যিই দেখানোর মতো ট্যাব (চালু + দরকারি লিংক/ক্যাটাগরি দেওয়া আছে)
  List<TopTabItem> visible(AppSettings s) {
    if (!enabled) return const [];
    bool ok(TopTabItem t) {
      if (t.type == 'story' || t.type == 'epaper') return true; // রিলস ও ই-পেপার সবসময় থাকে
      if (!t.on) return false;
      switch (t.type) {
        case 'home':
        case 'latest':
        case 'videos':
        case 'search':
        case 'notifications':
        case 'photocard':
        case 'story': // এখনো ভেতরে কিছু নেই: "শীঘ্রই আসছে" পেজ দেখায়
          return true;
        case 'category':
          return true; // ক্যাটাগরি বাছা না থাকলে (যেমন স্টোরি) "শীঘ্রই আসছে" পেজ
        case 'link':
          return t.target.startsWith('https://');
        case 'epaper':
          return true; // লিংক থাকলে ব্রাউজারে খোলে, না থাকলে "শীঘ্রই আসছে" পেজ
        case 'tv':
          return s.liveTv.url.isNotEmpty;
        default:
          return false;
      }
    }

    final list = items.where(ok).map((t) {
      // পুরনো সেভ করা ডিজাইনের "স্টোরি" ট্যাব এখন "রিলস"
      if (t.type == 'story' && (t.label.isEmpty || t.label == 'স্টোরি')) {
        return TopTabItem(id: t.id, label: 'রিলস', icon: 'story', iconUrl: t.iconUrl, type: 'story');
      }
      return t;
    }).toList();
    // "সর্বশেষ" ট্যাব বাদ; ই-কমার্স সবার শেষে (অ্যাডমিনের তালিকায় যা-ই থাকুক)
    list.removeWhere((t) => t.type == 'latest');
    list.removeWhere((t) => t.type == 'link' && t.target.contains('shop.amarsokal24.com'));
    // অ্যাডমিনের সেভ করা তালিকায় না থাকলেও ট্যাব পূর্ণ করা
    if (!list.any((t) => t.type == 'story')) {
      list.add(const TopTabItem(id: 'ts', label: 'রিলস', icon: 'story', type: 'story'));
    }
    if (!list.any((t) => t.type == 'epaper')) {
      list.add(const TopTabItem(id: 'te', label: 'ই-পেপার', icon: 'paper', type: 'epaper'));
    }
    // "ফটো কার্ড" হোমের ঠিক পাশে
    if (!list.any((t) => t.type == 'photocard')) {
      final hi = list.indexWhere((t) => t.type == 'home');
      list.insert(hi < 0 ? 0 : hi + 1, const TopTabItem(id: 'tpc', label: 'ফটো কার্ড', icon: 'photo', type: 'photocard'));
    }
    list.add(const TopTabItem(id: 'tshop', label: 'ই-কমার্স', icon: 'shop', type: 'link', target: 'https://shop.amarsokal24.com/'));
    return list;
  }
}

class CardConf {
  final String style; // small | compact | big | overlay | grid
  final double radius;
  final bool showCategory, showTime, showExcerpt, imageRight;
  const CardConf({
    this.style = 'small',
    this.radius = 8,
    this.showCategory = true,
    this.showTime = true,
    this.showExcerpt = false,
    this.imageRight = false,
  });

  factory CardConf.fromJson(Map<String, dynamic> j) => CardConf(
        style: const ['small', 'compact', 'big', 'overlay', 'grid'].contains(_s(j['style'])) ? _s(j['style']) : 'small',
        radius: _d(j['radius'], 8).clamp(0, 24).toDouble(),
        showCategory: _b(j['showCategory'], true),
        showTime: _b(j['showTime'], true),
        showExcerpt: _b(j['showExcerpt'], false),
        imageRight: _b(j['imageRight'], false),
      );
}

/// ব্যানার বা বিজ্ঞাপনের একটি আইটেম
class PromoItem {
  final String id, slot, image, link;
  final double ratio; // ০ মানে ছবির নিজস্ব অনুপাত
  const PromoItem({required this.id, required this.slot, required this.image, required this.link, required this.ratio});

  factory PromoItem.fromJson(Map<String, dynamic> j) => PromoItem(
        id: _s(j['id']),
        slot: _s(j['slot']).isEmpty ? 'main' : _s(j['slot']),
        image: _s(j['image']),
        link: _s(j['link']),
        ratio: _d(j['ratio'], 0),
      );
}

class PopupConf {
  final bool on;
  final String id, title, text, image, link, button, frequency;
  const PopupConf({
    this.on = false,
    this.id = '',
    this.title = '',
    this.text = '',
    this.image = '',
    this.link = '',
    this.button = 'বিস্তারিত',
    this.frequency = 'daily',
  });

  factory PopupConf.fromJson(Map<String, dynamic> j) => PopupConf(
        on: _b(j['on'], false),
        id: _s(j['id']),
        title: _s(j['title']),
        text: _s(j['text']),
        image: _s(j['image']),
        link: _s(j['link']),
        button: _s(j['button']).isEmpty ? 'বিস্তারিত' : _s(j['button']),
        frequency: const ['once', 'daily', 'always'].contains(_s(j['frequency'])) ? _s(j['frequency']) : 'daily',
      );
}

class BreakingConf {
  final bool on;
  final String label, source;
  final List<String> items;
  final Color color, bg;
  final int count;
  const BreakingConf({
    this.on = false,
    this.label = 'ব্রেকিং',
    this.source = 'manual',
    this.items = const [],
    this.color = Colors.white,
    this.bg = AppConfig.brand,
    this.count = 5,
  });

  factory BreakingConf.fromJson(Map<String, dynamic> j) => BreakingConf(
        on: _b(j['on'], false),
        label: _s(j['label']).isEmpty ? 'ব্রেকিং' : _s(j['label']),
        source: _s(j['source']) == 'latest' ? 'latest' : 'manual',
        items: _l(j['items']).map(_s).where((e) => e.isNotEmpty).toList(),
        color: _c(j['color'], Colors.white),
        bg: _c(j['bg'], AppConfig.brand),
        count: _i(j['count'], 5).clamp(1, 10).toInt(),
      );
}

/// লাইভ টিভি / ই-পেপার কার্ড
class LinkBox {
  final bool on;
  final String title, url, image;
  const LinkBox({this.on = false, this.title = '', this.url = '', this.image = ''});

  factory LinkBox.fromJson(Map<String, dynamic> j, String fallbackTitle) => LinkBox(
        on: _b(j['on'], false),
        title: _s(j['title']).isEmpty ? fallbackTitle : _s(j['title']),
        url: _s(j['url']),
        image: _s(j['image']),
      );
}

class MenuItemConf {
  final String label, type, target;
  const MenuItemConf({required this.label, required this.type, required this.target});

  factory MenuItemConf.fromJson(Map<String, dynamic> j) =>
      MenuItemConf(label: _s(j['label']), type: _s(j['type']), target: _s(j['target']));
}

class MaintenanceConf {
  final bool on;
  final String title, message;
  const MaintenanceConf({this.on = false, this.title = 'রক্ষণাবেক্ষণ চলছে', this.message = 'কিছুক্ষণ পরে আবার চেষ্টা করুন।'});

  factory MaintenanceConf.fromJson(Map<String, dynamic> j) => MaintenanceConf(
        on: _b(j['on'], false),
        title: _s(j['title']).isEmpty ? 'রক্ষণাবেক্ষণ চলছে' : _s(j['title']),
        message: _s(j['message']).isEmpty ? 'কিছুক্ষণ পরে আবার চেষ্টা করুন।' : _s(j['message']),
      );
}

class UpdateConf {
  final int minBuild;
  final String message, url;
  const UpdateConf({this.minBuild = 0, this.message = 'অ্যাপের নতুন সংস্করণ এসেছে। আপডেট করুন।', this.url = ''});

  factory UpdateConf.fromJson(Map<String, dynamic> j) => UpdateConf(
        minBuild: _i(j['minBuild'], 0),
        message: _s(j['message']).isEmpty ? 'অ্যাপের নতুন সংস্করণ এসেছে। আপডেট করুন।' : _s(j['message']),
        url: _s(j['url']),
      );
}

class AppSettings {
  final int version; // সার্ভারের Configuration Version (০ = ডিফল্ট)
  final String appName;
  final Color brand;
  final ThemeConf theme;
  final LogoConf logo;
  final HeaderConf header;
  final NavConf nav;
  final TopTabsConf topTabs;
  final CardConf cards;
  final List<SectionConf> sections;
  final List<PromoItem> banners, ads;
  final PopupConf popup;
  final BreakingConf breaking;
  final LinkBox liveTv, epaper;
  final List<MenuItemConf> menu;
  final MaintenanceConf maintenance;
  final UpdateConf update;

  AppSettings({
    required this.version,
    required this.appName,
    required this.brand,
    required this.theme,
    required this.logo,
    required this.header,
    required this.nav,
    required this.topTabs,
    required this.cards,
    required this.sections,
    required this.banners,
    required this.ads,
    required this.popup,
    required this.breaking,
    required this.liveTv,
    required this.epaper,
    required this.menu,
    required this.maintenance,
    required this.update,
  });

  /// বর্তমান সক্রিয় সেটিংস (ConfigStore এটি আপডেট করে)
  static AppSettings current = AppSettings.defaults();

  /// নেট না থাকলে/সেটিংস না এলে এই ডিফল্ট চলে (আগের অ্যাপের মতোই)
  factory AppSettings.defaults() => AppSettings(
        version: 0,
        appName: AppConfig.appName,
        brand: AppConfig.brand,
        theme: ThemeConf.defaults(),
        logo: const LogoConf(),
        header: const HeaderConf(),
        nav: NavConf.defaults(),
        topTabs: TopTabsConf.defaults(),
        cards: const CardConf(),
        sections: [
          SectionConf(type: 'chips', title: '', count: 0, category: 0, on: true),
          SectionConf(type: 'hero', title: '', count: 1, category: 0, on: true),
          SectionConf(type: 'latest', title: 'সর্বশেষ', count: 5, category: 0, on: true),
          SectionConf(type: 'videos', title: 'ভিডিও', count: 6, category: 0, on: true),
          SectionConf(type: 'latest', title: 'আরও খবর', count: 9, category: 0, on: true),
        ],
        banners: const [],
        ads: const [],
        popup: const PopupConf(),
        breaking: const BreakingConf(),
        liveTv: const LinkBox(title: 'লাইভ টিভি'),
        epaper: const LinkBox(title: 'ই-পেপার'),
        menu: const [],
        maintenance: const MaintenanceConf(),
        update: const UpdateConf(),
      );

  /// ভুল হলে Exception ছোড়ে; ConfigStore তখন নতুন কনফিগ গ্রহণ করে না (আগেরটাই থাকে)।
  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final name = _s(j['appName']);
    final brand = _c(j['brandColor'], AppConfig.brand);
    final secs = _l(j['sections']).map((e) => SectionConf.fromJson(_m(e))).where((s) => s.type.isNotEmpty).toList();
    return AppSettings(
      version: _i(j['version'], 0),
      appName: name.isEmpty ? AppConfig.appName : name,
      brand: brand,
      theme: ThemeConf.fromJson(_m(j['theme']), brand),
      logo: LogoConf.fromJson(_m(j['logo'])),
      header: HeaderConf.fromJson(_m(j['header'])),
      nav: j['bottomNav'] is Map ? NavConf.fromJson(_m(j['bottomNav'])) : NavConf.defaults(),
      topTabs: j['topTabs'] is Map ? TopTabsConf.fromJson(_m(j['topTabs'])) : TopTabsConf.defaults(),
      cards: CardConf.fromJson(_m(j['cards'])),
      sections: secs.isEmpty ? AppSettings.defaults().sections : secs,
      banners: _l(j['banners']).map((e) => PromoItem.fromJson(_m(e))).where((p) => p.image.isNotEmpty).toList(),
      ads: _l(j['ads']).map((e) => PromoItem.fromJson(_m(e))).where((p) => p.image.isNotEmpty).toList(),
      popup: PopupConf.fromJson(_m(j['popup'])),
      breaking: BreakingConf.fromJson(_m(j['breaking'])),
      liveTv: LinkBox.fromJson(_m(j['liveTv']), 'লাইভ টিভি'),
      epaper: LinkBox.fromJson(_m(j['epaper']), 'ই-পেপার'),
      menu: _l(j['menu']).map((e) => MenuItemConf.fromJson(_m(e))).where((m) => m.label.isNotEmpty).toList(),
      maintenance: MaintenanceConf.fromJson(_m(j['maintenance'])),
      update: UpdateConf.fromJson(_m(j['update'])),
    );
  }
}
