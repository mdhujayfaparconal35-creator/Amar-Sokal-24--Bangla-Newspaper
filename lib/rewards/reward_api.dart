import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class RewardError implements Exception {
  final String message;
  final int status;
  RewardError(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

int ri(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

/// কয়েন/রিওয়ার্ড সার্ভারের (ওয়ার্ডপ্রেস প্লাগইন asr/v1) সাথে কথা বলে।
/// সব হিসাব ও যাচাই সার্ভারে হয়; অ্যাপ শুধু দেখায় ও অনুরোধ পাঠায়।
class RewardApi {
  static String get base => '${Uri.parse(AppConfig.apiBase).origin}/wp-json/asr/v1';

  static String? _token;
  static String _device = '';

  static final ValueNotifier<bool> loggedIn = ValueNotifier<bool>(false);
  static final ValueNotifier<Map<String, dynamic>?> me = ValueNotifier<Map<String, dynamic>?>(null);

  /// সার্ভার থেকে আসা নিয়মের কপি (আসার আগে ডিফল্ট)
  static Map<String, dynamic> cfg = {
    'open': 1,
    'read_coin': 1,
    'read_seconds': 30,
    'read_daily_max': 70,
    'share_coin': 10,
    'share_daily_max': 3,
    'coins_per_taka': 100,
    'min_withdraw': 20,
    'fb_page_url': '',
    'notice': '',
  };

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _token = p.getString('asr_token');
      var d = p.getString('asr_dev');
      if (d == null || d.length < 16) {
        final r = Random.secure();
        const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        d = List.generate(28, (_) => chars[r.nextInt(chars.length)]).join();
        await p.setString('asr_dev', d);
      }
      _device = d;
      loggedIn.value = _token != null && _token!.isNotEmpty;
      if (loggedIn.value) unawaited(refreshMe().then((_) {}).catchError((_) {}));
    } catch (_) {}
  }

  static Future<void> _setToken(String? t) async {
    _token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('asr_token');
      me.value = null;
    } else {
      await p.setString('asr_token', t);
    }
    loggedIn.value = t != null;
  }

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_token != null) 'X-ASR-Token': _token!,
      };

  static Map<String, dynamic> _parse(http.Response r) {
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) return j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
    final code = (j is Map && j['code'] != null) ? '${j['code']}' : '';
    // টোকেন অচল হলে (asr_auth) লগআউট; অন্য ৪০১ (যেমন ভুল পাসওয়ার্ড) নয়
    if (r.statusCode == 401 && code == 'asr_auth') _setToken(null);
    if (r.statusCode == 404 && !code.startsWith('asr_')) {
      throw RewardError('রিওয়ার্ড সার্ভিস এখনো চালু হয়নি।', 404);
    }
    final msg = (j is Map && j['message'] != null) ? '${j['message']}' : 'সমস্যা হয়েছে (${r.statusCode})';
    throw RewardError(msg, r.statusCode);
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final r = await http.get(Uri.parse('$base$path'), headers: _headers).timeout(const Duration(seconds: 20));
      return _parse(r);
    } on RewardError {
      rethrow;
    } catch (_) {
      throw RewardError('ইন্টারনেট সংযোগ নেই বা সার্ভার সাড়া দিচ্ছে না।');
    }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, String> form) async {
    try {
      final r = await http.post(Uri.parse('$base$path'), headers: _headers, body: form).timeout(const Duration(seconds: 25));
      return _parse(r);
    } on RewardError {
      rethrow;
    } catch (_) {
      throw RewardError('ইন্টারনেট সংযোগ নেই বা সার্ভার সাড়া দিচ্ছে না।');
    }
  }

  static Future<void> loadConfig() async {
    try {
      final j = await _get('/config');
      cfg = {...cfg, ...j};
    } catch (_) {}
  }

  static Future<void> register(String name, String email, String password) async {
    final j = await _post('/register', {'name': name, 'email': email, 'password': password, 'device_id': _device});
    await _setToken('${j['token']}');
    await refreshMe();
  }

  static Future<void> login(String email, String password) async {
    final j = await _post('/login', {'email': email, 'password': password, 'device_id': _device});
    await _setToken('${j['token']}');
    await refreshMe();
  }

  static Future<void> logout() async {
    try {
      await _post('/logout', {});
    } catch (_) {}
    await _setToken(null);
  }

  static Future<Map<String, dynamic>> refreshMe() async {
    final j = await _get('/me');
    if (j['config'] is Map) cfg = {...cfg, ...Map<String, dynamic>.from(j['config'] as Map)};
    me.value = j;
    return j;
  }

  static Future<List<Map<String, dynamic>>> _items(String path) async {
    final j = await _get(path);
    final l = j['items'];
    return l is List ? l.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> ledger() => _items('/ledger');
  static Future<List<Map<String, dynamic>>> shares() => _items('/shares');
  static Future<List<Map<String, dynamic>>> withdrawals() => _items('/withdrawals');

  static Future<Map<String, dynamic>> readStart(int postId) => _post('/read/start', {'post_id': '$postId'});
  static Future<Map<String, dynamic>> readClaim(int postId) => _post('/read/claim', {'post_id': '$postId'});

  /// দৈনিক চেক-ইন (সার্ভারে দিনে একবারই কয়েন যোগ হয়)
  static Future<Map<String, dynamic>> checkin() async {
    final j = await _post('/checkin', {});
    await refreshMe();
    return j;
  }

  static Future<Map<String, dynamic>> withdraw(String bkash) async {
    final j = await _post('/withdraw', {'bkash': bkash});
    await refreshMe();
    return j;
  }

  /// ফেসবুক শেয়ার + পেজ ফলোর দুটি স্ক্রিনশট জমা
  static Future<Map<String, dynamic>> submitShare(int postId, String shareShot, String followShot) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$base/share/submit'))
        ..headers.addAll(_headers)
        ..fields['post_id'] = '$postId'
        ..files.add(await http.MultipartFile.fromPath('shot_share', shareShot))
        ..files.add(await http.MultipartFile.fromPath('shot_follow', followShot));
      final streamed = await req.send().timeout(const Duration(seconds: 90));
      final r = await http.Response.fromStream(streamed);
      final j = _parse(r);
      unawaited(refreshMe().then((_) {}).catchError((_) {}));
      return j;
    } on RewardError {
      rethrow;
    } catch (_) {
      throw RewardError('ছবি পাঠানো যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।');
    }
  }
}
