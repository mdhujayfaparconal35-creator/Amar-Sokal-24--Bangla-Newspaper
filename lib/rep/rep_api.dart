import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../rewards/reward_api.dart';
import '../sys_notify.dart';

/// প্রতিনিধি অ্যাপের সার্ভার (T2: rep_api.php)। লগইন = ডাটাবেজ নাম্বার + পাসওয়ার্ড।
/// নিউজ জমা হয় T2-তে; যাচাইয়ের পর প্রকাশ/বাতিলের নোটিফিকেশন এখান থেকে আসে।
class RepApi {
  static const String base = '${AppConfig.t2Base}/rep_api.php';

  static String? _token;
  static String? get token => _token;

  static final ValueNotifier<bool> loggedIn = ValueNotifier<bool>(false);
  static final ValueNotifier<Map<String, dynamic>?> rep = ValueNotifier<Map<String, dynamic>?>(null);

  /// নতুন নোটিফিকেশন এলে বাড়ে — প্রতিনিধি পেজ এটা দেখে তালিকা নতুন করে আনে
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static String randomId([int n = 20]) {
    const c = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(n, (_) => c[r.nextInt(c.length)]).join();
  }

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _token = p.getString('rep_token');
      final saved = p.getString('rep_info');
      if (saved != null) {
        try {
          rep.value = Map<String, dynamic>.from(jsonDecode(saved) as Map);
        } catch (_) {}
      }
      loggedIn.value = _token != null && _token!.isNotEmpty;
      if (loggedIn.value) unawaited(me().then((_) => linkReward()).catchError((_) {}));
    } catch (_) {}
  }

  static Future<void> _setSession(String? token, Map<String, dynamic>? info) async {
    _token = token;
    final p = await SharedPreferences.getInstance();
    if (token == null) {
      await p.remove('rep_token');
      await p.remove('rep_info');
      await p.remove('rep_notif_last');
      rep.value = null;
    } else {
      await p.setString('rep_token', token);
      if (info != null) {
        await p.setString('rep_info', jsonEncode(info));
        rep.value = info;
      }
    }
    loggedIn.value = token != null;
  }

  static Map<String, String> get _headers => {'Accept': 'application/json', if (_token != null) 'X-Rep-Token': _token!};

  static Map<String, dynamic> _parse(http.Response r, {bool isLogin = false}) {
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    final ok = r.statusCode >= 200 && r.statusCode < 300;
    if (ok) return j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
    if (!isLogin && r.statusCode == 401 && j is Map && j['code'] == 'rep_auth') _setSession(null, null);
    if (r.statusCode == 404 && !(j is Map && j['msg'] != null)) throw RewardError('প্রতিনিধি সার্ভিস এখনো চালু হয়নি।', 404);
    throw RewardError(j is Map && j['msg'] != null ? '${j['msg']}' : 'সমস্যা হয়েছে (${r.statusCode})', r.statusCode);
  }

  static Future<Map<String, dynamic>> _get(String a, {Map<String, String>? q}) async {
    try {
      final u = Uri.parse(base).replace(queryParameters: {'a': a, ...?q});
      return _parse(await http.get(u, headers: _headers).timeout(const Duration(seconds: 20)));
    } on RewardError {
      rethrow;
    } catch (_) {
      throw RewardError('ইন্টারনেট সংযোগ নেই বা সার্ভার সাড়া দিচ্ছে না।');
    }
  }

  static Future<Map<String, dynamic>> _post(String a, Map<String, String> form, {bool isLogin = false}) async {
    try {
      final u = Uri.parse(base).replace(queryParameters: {'a': a});
      return _parse(await http.post(u, headers: _headers, body: form).timeout(const Duration(seconds: 25)), isLogin: isLogin);
    } on RewardError {
      rethrow;
    } catch (_) {
      throw RewardError('ইন্টারনেট সংযোগ নেই বা সার্ভার সাড়া দিচ্ছে না।');
    }
  }

  /// ধাপ ১: নাম্বার দিলে প্রতিনিধির তথ্য ও পাসওয়ার্ড তৈরি আছে কি না জানা
  static Future<Map<String, dynamic>> lookup(String code) => _post('lookup', {'code': code}, isLogin: true);

  /// প্রতিনিধিও কয়েন পাবেন: প্রতিনিধি-লগইনের সাথে তাঁর নিজস্ব রিওয়ার্ড অ্যাকাউন্ট যুক্ত হয়ে যায়
  static Future<void> linkReward() async {
    final t = _token;
    if (t == null || RewardApi.loggedIn.value) return;
    try {
      await RewardApi.linkRep(t);
    } catch (_) {}
  }

  /// পাসওয়ার্ড ভুলে গেলে: অফিসে রিসেটের অনুরোধ (অনুমোদনের পর নতুন পাসওয়ার্ড তৈরি করা যায়)
  static Future<String> resetRequest(String code) async {
    final j = await _post('reset_request', {'code': code}, isLogin: true);
    return '${j['msg'] ?? 'অনুরোধ পাঠানো হয়েছে।'}';
  }

  static Future<void> _startSession(Map<String, dynamic> j) async {
    await _setSession('${j['token']}', j['rep'] is Map ? Map<String, dynamic>.from(j['rep'] as Map) : <String, dynamic>{});
    unawaited(linkReward());
    // লগইনের আগের নোটিফিকেশন আর দেখাবে না — এখন থেকে নতুনগুলো
    try {
      final n = await _get('notifs', q: {'since': '0'});
      final p = await SharedPreferences.getInstance();
      await p.setInt('rep_notif_last', ri(n['latest']));
    } catch (_) {}
  }

  static Future<void> login(String code, String password) async {
    final j = await _post('login', {'code': code, 'password': password, 'device': 'app'}, isLogin: true);
    await _startSession(j);
  }

  /// প্রথমবার: প্রতিনিধি নিজেই পাসওয়ার্ড তৈরি করেন। অফিসের অনুমোদন লাগলে {pending: true, msg} ফেরে (লগইন হয় না)।
  static Future<Map<String, dynamic>> setup(String code, String password) async {
    final j = await _post('setup', {'code': code, 'password': password, 'device': 'app'}, isLogin: true);
    if (j['token'] != null) await _startSession(j);
    return j;
  }

  static Future<void> logout() async {
    try {
      await _post('logout', {});
    } catch (_) {}
    await _setSession(null, null);
    await RewardApi.logout(); // প্রতিনিধির যুক্ত রিওয়ার্ড অ্যাকাউন্ট থেকেও বের
  }

  /// প্রতিনিধির তথ্য, সংখ্যা (অপেক্ষমাণ/প্রকাশিত/বাতিল), আজকের জমা ও সীমা
  static Future<Map<String, dynamic>> me() async {
    final j = await _get('me');
    if (j['rep'] is Map) {
      final info = Map<String, dynamic>.from(j['rep'] as Map);
      rep.value = info;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('rep_info', jsonEncode(info));
      } catch (_) {}
    }
    return j;
  }

  static Future<List<String>> categories() async {
    final j = await _get('categories');
    final l = j['items'];
    return l is List ? l.map((e) => '$e').toList() : <String>[];
  }

  static Future<List<Map<String, dynamic>>> myNews() async {
    final j = await _get('my_news');
    final l = j['items'];
    return l is List ? l.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> submit({required String title, required String body, required String category, required String imagePath, required String uid}) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(base).replace(queryParameters: {'a': 'submit'}))
        ..headers.addAll(_headers)
        ..fields['title'] = title
        ..fields['body'] = body
        ..fields['category'] = category
        ..fields['client_uid'] = uid
        ..files.add(await http.MultipartFile.fromPath('image', imagePath));
      final streamed = await req.send().timeout(const Duration(seconds: 120));
      final j = _parse(await http.Response.fromStream(streamed));
      tick.value++;
      return j;
    } on RewardError {
      rethrow;
    } catch (_) {
      throw RewardError('নিউজ পাঠানো যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন (লেখা মুছবে না)।');
    }
  }

  static Future<void> changePassword(String oldPass, String newPass) async {
    final j = await _post('change_pass', {'old': oldPass, 'new': newPass});
    final p = await SharedPreferences.getInstance();
    await _setSession('${j['token']}', rep.value ?? (jsonDecode(p.getString('rep_info') ?? '{}') as Map).cast<String, dynamic>());
  }

  /// নতুন নোটিফিকেশন (প্রকাশিত/বাতিল) থাকলে ফোনের বারে দেখায়। অ্যাপ খোলা বা বন্ধ — দুই অবস্থাতেই চলে
  /// (ব্যাকগ্রাউন্ড অ্যালার্মেও এটা ডাকা হয়)।
  static Future<void> pollAndShow() async {
    try {
      final p = await SharedPreferences.getInstance();
      final tok = p.getString('rep_token');
      if (tok == null || tok.isEmpty) return;
      _token = tok;
      final since = p.getInt('rep_notif_last') ?? 0;
      final j = await _get('notifs', q: {'since': '$since'});
      final items = j['items'] is List ? (j['items'] as List) : const [];
      for (final it in items) {
        final m = Map<String, dynamic>.from(it as Map);
        await SysNotify.showRep(
          id: ri(m['id']),
          title: '${m['title'] ?? ''}',
          body: '${m['body'] ?? ''}',
          payload: jsonEncode({'t': 'rep', 'url': '${m['url'] ?? ''}'}),
        );
      }
      if (items.isNotEmpty) {
        await p.setInt('rep_notif_last', ri(j['latest']));
        tick.value++;
      }
    } catch (_) {}
  }
}
