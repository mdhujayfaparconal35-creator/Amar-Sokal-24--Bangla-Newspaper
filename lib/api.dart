import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'models.dart';

class _Entry {
  final DateTime time;
  final dynamic data;
  _Entry(this.time, this.data);
}

/// সার্ভারে চাপ কমাতে অ্যাপ নিজেও ৬০ সেকেন্ড মেমোরিতে ক্যাশ রাখে।
class Api {
  static final Map<String, _Entry> _mem = {};
  static const int _ttl = 60;

  static void clearCache() => _mem.clear();

  static Future<dynamic> _get(String path, {Map<String, String>? q, int ttl = _ttl}) async {
    final uri = Uri.parse('${AppConfig.apiBase}$path').replace(queryParameters: q);
    final key = uri.toString();
    final hit = _mem[key];
    if (hit != null && DateTime.now().difference(hit.time).inSeconds < ttl) {
      return hit.data;
    }
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    _mem[key] = _Entry(DateTime.now(), data);
    return data;
  }

  /// হোম: নেট না থাকলে শেষবার দেখা ডাটা দেখায়।
  static Future<HomeData> home() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final d = await _get('/home');
      await prefs.setString('home_cache', jsonEncode(d));
      return HomeData.fromJson(Map<String, dynamic>.from(d));
    } catch (e) {
      final saved = prefs.getString('home_cache');
      if (saved != null) {
        return HomeData.fromJson(Map<String, dynamic>.from(jsonDecode(saved)));
      }
      rethrow;
    }
  }

  static Future<List<NewsItem>> posts({int? category, String? search, int page = 1, int perPage = 15}) async {
    final q = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      if (category != null) 'category': '$category',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final d = await _get('/posts', q: q);
    return (d['items'] as List).map((e) => NewsItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<NewsDetail> post(int id) async {
    final d = await _get('/post/$id', ttl: 300);
    return NewsDetail.fromJson(Map<String, dynamic>.from(d));
  }

  static Future<List<VideoItem>> videos({int page = 1}) async {
    final d = await _get('/videos', q: {'page': '$page'});
    return (d['items'] as List).map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}


/// Remote Configuration: অ্যাডমিন প্যানেলে Publish করা ডিজাইন/সেটিংস।
///
/// নিয়ম:
///  1. অ্যাপ চালু হলে আগের ক্যাশ করা কনফিগ সাথে সাথে চলে (নেট না থাকলেও আগের ডিজাইন দেখা যায়)।
///  2. পেছনে সার্ভার থেকে নতুন version আছে কিনা দেখে; থাকলে নামিয়ে ক্যাশ করে ও সাথে সাথে UI বদলে দেয়।
///  3. পার্স করা না গেলে (ভুল/অসম্পূর্ণ কনফিগ) নতুনটা গ্রহণ ও ক্যাশ করা হয় না; আগেরটাই চলে।
///  4. অ্যাপ খোলা থাকলে/ফিরে এলে নির্দিষ্ট সময় পর পর আবার দেখে।
class ConfigStore {
  static final ValueNotifier<AppSettings> notifier = ValueNotifier<AppSettings>(AppSettings.defaults());
  static bool hasCache = false;
  static DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _busy = false;

  static void _apply(AppSettings s) {
    AppSettings.current = s;
    notifier.value = s;
  }

  /// ক্যাশ থেকে (ইন্টারনেট ছাড়াই)
  static Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('cfg_cache');
      if (saved == null) return;
      final s = AppSettings.fromJson(Map<String, dynamic>.from(jsonDecode(saved)));
      hasCache = true;
      _apply(s);
    } catch (_) {
      // নষ্ট ক্যাশ: ডিফল্টেই চলবে
    }
  }

  /// সার্ভার থেকে নতুন কনফিগ আছে কিনা দেখে। নতুন গ্রহণ করলে true।
  static Future<bool> refresh({Duration timeout = const Duration(seconds: 10)}) async {
    if (_busy) return false;
    _busy = true;
    try {
      final have = AppSettings.current.version;
      final q = <String, String>{if (hasCache && have > 0) 'v': '$have'};
      final uri = Uri.parse('${AppConfig.apiBase}/config').replace(queryParameters: q.isEmpty ? null : q);
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (AppConfig.apiKey.isNotEmpty) 'X-AS-Key': AppConfig.apiKey,
      }).timeout(timeout);
      _lastCheck = DateTime.now();
      if (res.statusCode != 200) return false;
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      if (d is! Map) return false;
      final map = Map<String, dynamic>.from(d);
      if (map['changed'] == false) return false; // একই version, কিছু বদলায়নি
      final s = AppSettings.fromJson(map); // ভুল হলে এখানেই Exception => গ্রহণ হবে না
      if (s.version > 0 && s.version < have) return false; // পুরনো/ক্যাশ হওয়া উত্তর উপেক্ষা
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cfg_cache', jsonEncode(map));
      hasCache = true;
      _apply(s);
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  /// অ্যাপে ফিরে এলে/টাইমারে: শেষ চেক থেকে নির্দিষ্ট সময় পেরোলেই।
  static Future<void> refreshIfStale() async {
    final mins = DateTime.now().difference(_lastCheck).inMinutes;
    if (mins >= AppConfig.configRefreshMinutes) await refresh();
  }
}
