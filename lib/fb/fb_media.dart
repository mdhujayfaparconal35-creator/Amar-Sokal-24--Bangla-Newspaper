import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// ফেসবুক পেজের একটি ভিডিও/রিল (T2: videos_api.php / reels_api.php থেকে)
class FbVideo {
  final String id, title, thumb, url, permalink, kind;
  final double length;
  final int w, h;
  final String created;
  const FbVideo({
    required this.id,
    required this.title,
    required this.thumb,
    required this.url,
    required this.permalink,
    required this.kind,
    required this.length,
    required this.w,
    required this.h,
    required this.created,
  });

  factory FbVideo.fromJson(Map<String, dynamic> j) => FbVideo(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}'.trim(),
        thumb: '${j['thumb'] ?? ''}',
        url: '${j['url'] ?? ''}',
        permalink: '${j['permalink'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        length: double.tryParse('${j['length'] ?? 0}') ?? 0,
        w: int.tryParse('${j['w'] ?? 0}') ?? 0,
        h: int.tryParse('${j['h'] ?? 0}') ?? 0,
        created: '${j['created'] ?? ''}',
      );

  bool get square => kind == 'square';

  /// প্লেয়ারে ব্যবহারের মাপ (জানা না থাকলে ১৬:৯ / ১:১)
  double get aspect {
    if (w > 0 && h > 0) return w / h;
    return square ? 1.0 : 16 / 9;
  }

  /// "০:৪৫" / "১২:০৫"
  String get lengthText {
    final s = length.round();
    if (s <= 0) return '';
    final m = s ~/ 60;
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }
}

class FbFeed {
  final List<FbVideo> items;
  final String? error;
  const FbFeed(this.items, [this.error]);
}

/// ভিডিও ও রিলসের তালিকা। আগেরবারের তালিকা ফোনে রাখা থাকে — পেজ খুললেই সাথে সাথে দেখায়,
/// পেছনে নতুনটা এনে বদলে দেয় (ফেসবুকের ভিডিও-লিংক মেয়াদ হারায়, তাই নতুনটাই আসল)।
class FbMedia {
  static const String _videosUrl = '${AppConfig.t2Base}/videos_api.php';
  static const String _reelsUrl = '${AppConfig.t2Base}/reels_api.php';

  static Future<FbFeed?> cached(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('fbm_$key');
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map;
      final at = (m['at'] as num?)?.toInt() ?? 0;
      // ৬ ঘণ্টার বেশি পুরোনো হলে ভিডিও-লিংক চলবে না, শুধু থাম্বনেইল-তালিকা হিসেবেও না রাখা ভালো
      if (DateTime.now().millisecondsSinceEpoch - at > 6 * 3600 * 1000) return null;
      final list = (m['items'] as List).map((e) => FbVideo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return list.isEmpty ? null : FbFeed(list);
    } catch (_) {
      return null;
    }
  }

  static Future<FbFeed> _fetch(String url, String key) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final list = (j is Map && j['items'] is List) ? (j['items'] as List) : const [];
      final items = list.map((e) => FbVideo.fromJson(Map<String, dynamic>.from(e as Map))).where((e) => e.url.startsWith('http')).toList();
      if (items.isEmpty) {
        return FbFeed(const [], (j is Map && j['msg'] != null) ? '${j['msg']}' : 'এখন কিছু পাওয়া যাচ্ছে না।');
      }
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(
          'fbm_$key',
          jsonEncode({
            'at': DateTime.now().millisecondsSinceEpoch,
            'items': [
              for (final v in items)
                {'id': v.id, 'title': v.title, 'thumb': v.thumb, 'url': v.url, 'permalink': v.permalink, 'kind': v.kind, 'length': v.length, 'w': v.w, 'h': v.h, 'created': v.created}
            ],
          }),
        );
      } catch (_) {}
      return FbFeed(items);
    } catch (_) {
      return const FbFeed([], 'ইন্টারনেট সংযোগ নেই বা সার্ভার সাড়া দিচ্ছে না।');
    }
  }

  static Future<FbFeed> videos() => _fetch(_videosUrl, 'videos');
  static Future<FbFeed> reels() => _fetch(_reelsUrl, 'reels');
}
