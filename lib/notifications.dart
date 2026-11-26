import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';
import 'rewards/reward_screens.dart';
import 'screens/post_screen.dart';
import 'screens/video_player_screen.dart';
import 'sys_notify.dart';
import 'update_checker.dart';

/// পুরো অ্যাপের একটি Navigator চাবি: নোটিফিকেশনে ট্যাপ করলে যেকোনো জায়গা থেকে নিউজ/ভিডিও খোলে
final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

/// অ্যাপের ভেতরের নোটিফিকেশন তালিকার একটি সারি
class NotifEntry {
  final Map<String, dynamic> data; // t, id, title, date, thumb, (youtube)
  NotifEntry(this.data);
  bool get isVideo => data['t'] == 'video';
  int get id => (data['id'] as num).toInt();
  String get title => '${data['title'] ?? ''}';
  String get date => '${data['date'] ?? ''}';
  String get thumb => '${data['thumb'] ?? ''}';
}

/// নতুন নিউজ ও নতুন ভিডিওর নোটিফিকেশন:
///  ১) অ্যাপের "নোটিফিকেশন" ট্যাবের তালিকায় যোগ হয়
///  ২) ফোনের নোটিফিকেশন বারেও যায় (পূর্ণ ভার্সনে)
/// প্রথমবার শুধু "এখন যা আছে" তালিকায় তোলে (ফোনে পুরনো খবরের নোটিফিকেশন যায় না),
/// এরপর নতুন যা আসে তার জন্য একটি করে নোটিফিকেশন (একবারে সর্বোচ্চ ৩টি)।
class Notifier {
  static final ValueNotifier<List<NotifEntry>> history = ValueNotifier<List<NotifEntry>>([]);
  static String? _pending;
  static bool _checking = false;

  static const _kOn = 'notif_on';
  static const _kPosts = 'notif_seen_posts';
  static const _kVideos = 'notif_seen_videos';
  static const _kHist = 'notif_hist';

  /// আজ (ফোনের তারিখ অনুযায়ী) কয়টি নিউজ প্রকাশ হয়েছে — "নোটিফিকেশন" ট্যাবের লাল সংখ্যা; পরের দিন আবার ০ থেকে শুরু
  static final ValueNotifier<int> todayNews = ValueNotifier<int>(0);
  static const _kDay = 'notif_day';
  static const _kDayIds = 'notif_day_ids';

  static int todayCount([List<NotifEntry>? l]) => todayNews.value;

  static String _dayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// আজকের তারিখে সেভ করা নিউজ-আইডির সেট (দিন বদলালে ফাঁকা)
  static Set<String> _todayIds(SharedPreferences p) =>
      p.getString(_kDay) == _dayKey() ? (p.getStringList(_kDayIds) ?? <String>[]).toSet() : <String>{};

  /// সাইট থেকে আনা নিউজের মধ্যে আজকের তারিখের নিউজ গুনে সংখ্যা বসায় (একই নিউজ দুইবার গোনা হয় না)
  static Future<void> _trackToday(SharedPreferences p, List<NewsItem> posts) async {
    final ids = _todayIds(p);
    final now = DateTime.now();
    for (final x in posts) {
      final d = DateTime.tryParse(x.date);
      if (d == null) continue;
      final l = d.isUtc ? d.toLocal() : d;
      if (l.year == now.year && l.month == now.month && l.day == now.day) ids.add('${x.id}');
    }
    await p.setString(_kDay, _dayKey());
    await p.setStringList(_kDayIds, ids.toList());
    todayNews.value = ids.length;
  }

  static Future<void> start() => SysNotify.start();

  static Future<bool> isOn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kOn) ?? true;
  }

  static Future<void> setOn(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOn, v);
    if (v) await SysNotify.requestPermission();
  }

  static Future<void> loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final raw = p.getStringList(_kHist) ?? const [];
      final list = raw.map((e) => NotifEntry(Map<String, dynamic>.from(jsonDecode(e)))).toList();
      history.value = list;
      todayNews.value = _todayIds(p).length;
    } catch (_) {}
  }

  static Future<void> _addHistory(SharedPreferences prefs, List<Map<String, dynamic>> add) async {
    if (add.isEmpty) return;
    final raw = prefs.getStringList(_kHist) ?? <String>[];
    final cur = raw.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
    final keys = cur.map((e) => '${e['t']}_${e['id']}').toSet();
    for (final a in add) {
      if (keys.add('${a['t']}_${a['id']}')) cur.add(a);
    }
    cur.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    await prefs.setStringList(_kHist, cur.take(60).map((e) => jsonEncode(e)).toList());
    await loadHistory();
  }

  /// নতুন নিউজ/ভিডিও দেখে (ফোরগ্রাউন্ড ও ব্যাকগ্রাউন্ড দুই জায়গা থেকেই চলে)
  static Future<void> checkNew() async {
    if (_checking) return;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final on = prefs.getBool(_kOn) ?? true;
      await SysNotify.init();

      // নিউজ
      try {
        final posts = await Api.posts(perPage: 40);
        await _trackToday(prefs, posts);
        final seen = prefs.getStringList(_kPosts);
        Map<String, dynamic> entry(NewsItem p) => {'t': 'post', 'id': p.id, 'title': p.title, 'date': p.date, 'thumb': p.image};
        if (seen == null) {
          await _addHistory(prefs, posts.take(6).map(entry).toList()); // প্রথমবার: তালিকা ভরে, ফোনে নোটিফিকেশন নয়
        } else {
          final fresh = posts.where((p) => !seen.contains('${p.id}')).take(3).toList();
          await _addHistory(prefs, fresh.map(entry).toList());
          if (on) {
            for (final p in fresh.reversed) {
              await SysNotify.show(
                id: p.id,
                video: false,
                title: p.title,
                body: p.category?.name.isNotEmpty == true ? 'নতুন খবর • ${p.category!.name}' : 'নতুন খবর',
                image: p.image,
                payload: jsonEncode(entry(p)),
              );
            }
          }
        }
        await prefs.setStringList(_kPosts, {...posts.map((e) => '${e.id}'), ...?seen}.take(80).toList());
      } catch (_) {}

      // ভিডিও
      try {
        final vids = await Api.videos(page: 1);
        final seen = prefs.getStringList(_kVideos);
        Map<String, dynamic> entry(VideoItem v) => {'t': 'video', 'id': v.id, 'title': v.title, 'date': v.date, 'youtube': v.youtube, 'thumb': v.thumb};
        if (seen == null) {
          await _addHistory(prefs, vids.take(3).map(entry).toList());
        } else {
          final fresh = vids.where((v) => !seen.contains('${v.id}')).take(3).toList();
          await _addHistory(prefs, fresh.map(entry).toList());
          if (on) {
            for (final v in fresh.reversed) {
              await SysNotify.show(
                id: v.id,
                video: true,
                title: v.title,
                body: 'নতুন ভিডিও',
                image: v.thumb,
                payload: jsonEncode(entry(v)),
              );
            }
          }
        }
        await prefs.setStringList(_kVideos, {...vids.map((e) => '${e.id}'), ...?seen}.take(80).toList());
      } catch (_) {}
    } finally {
      _checking = false;
    }
  }

  /// নোটিফিকেশনে/তালিকায় ট্যাপ: নিউজ বা ভিডিও অ্যাপের ভেতরেই খোলে
  static Future<void> handlePayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    try {
      open(Map<String, dynamic>.from(jsonDecode(payload)));
    } catch (_) {}
  }

  static void open(Map<String, dynamic> m) {
    final nav = appNavKey.currentState;
    if (nav == null) {
      _pending = jsonEncode(m);
      return;
    }
    if (m['t'] == 'update') {
      UpdateChecker.onNotificationTap();
      return;
    }
    if (m['t'] == 'rep') {
      nav.push(MaterialPageRoute(builder: (_) => const RewardScreen())); // লগইন থাকলে প্রতিনিধি প্যানেল খোলে
      return;
    }
    final id = (m['id'] as num).toInt();
    if (m['t'] == 'video') {
      final v = VideoItem(
        id: id,
        title: '${m['title'] ?? ''}',
        date: '${m['date'] ?? ''}',
        youtube: '${m['youtube'] ?? ''}',
        thumb: '${m['thumb'] ?? ''}',
      );
      nav.push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: v)));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => PostScreen(id: id)));
    }
  }

  /// অ্যাপ বন্ধ থাকা অবস্থায় নোটিফিকেশনে ট্যাপ করে খুললে, হোম আঁকা হওয়ার পর সেটি খোলে
  static Future<void> handleLaunch() async {
    final p = await SysNotify.launchPayload();
    if (p != null) {
      await handlePayload(p);
    } else if (_pending != null) {
      final x = _pending;
      _pending = null;
      await handlePayload(x);
    }
  }
}
