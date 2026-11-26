import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'notifications.dart';
import 'sys_notify.dart';
import 'util.dart';

/// অ্যাডমিনের "📲 অ্যাপ আপডেট" ট্যাবে দেওয়া সর্বশেষ সংস্করণের তথ্য (T2: app_meta.php)
class UpdateInfo {
  final int build;
  final String version, url, notes, at;
  final bool force;
  const UpdateInfo({required this.build, required this.version, required this.url, required this.notes, required this.at, required this.force});

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        build: int.tryParse('${j['build'] ?? 0}') ?? 0,
        version: '${j['version'] ?? ''}'.trim(),
        url: '${j['url'] ?? ''}'.trim(),
        notes: '${j['notes'] ?? ''}'.trim(),
        at: '${j['at'] ?? ''}',
        force: j['force'] == true,
      );

  List<String> get noteLines => notes.split(RegExp(r'\r?\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

/// নতুন সংস্করণ এলে ব্যবহারকারী ও প্রতিনিধি — সবাইকে সুন্দর একটি বার্তা দেখায় ("এখনই আপডেট" / "পরে") এবং ফোনের নোটিফিকেশনেও জানায়।
/// "পরে" চাপলে একই সংস্করণের বার্তা ২৪ ঘণ্টা পর আবার আসে; বাধ্যতামূলক আপডেটে "পরে" নেই।
/// "এখনই আপডেট" চাপলে অ্যাপের ভেতরেই APK নামে (প্রগ্রেস দেখায়) ও ফোনের ইনস্টলার খোলে — ড্রাইভ/ব্রাউজারে যেতে হয় না।
/// অ্যাপ-ভেতরে ডাউনলোড না হলে (ফলব্যাক) আগের মতো ব্রাউজারে লিংক খোলে।
class UpdateChecker {
  static const String _url = '${AppConfig.t2Base}/app_meta.php';

  /// ইনস্টল-করা অ্যাপের চেয়ে নতুন সংস্করণ থাকলে সেটি (প্রতিনিধি প্যানেলের কার্ড এটা দেখে)
  static final ValueNotifier<UpdateInfo?> available = ValueNotifier<UpdateInfo?>(null);

  static bool _sheetOpen = false;
  static DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<UpdateInfo?> fetch() async {
    try {
      final r = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is! Map || j['update'] is! Map) return null;
      final info = UpdateInfo.fromJson(Map<String, dynamic>.from(j['update'] as Map));
      _lastFetch = DateTime.now();
      return info;
    } catch (_) {
      return null;
    }
  }

  static bool isNewer(UpdateInfo? i) => i != null && i.build > AppConfig.build && i.url.startsWith('http');

  /// প্রতিনিধি-প্যানেলের API থেকেও আপডেটের তথ্য আসে (আলাদা রিকোয়েস্ট ছাড়াই)
  static void applyFromMap(dynamic m) {
    if (m is! Map) return;
    final info = UpdateInfo.fromJson(Map<String, dynamic>.from(m));
    available.value = isNewer(info) ? info : null;
  }

  static Future<bool> _shouldShow(UpdateInfo i, {required bool ignoreSnooze}) async {
    if (i.force || ignoreSnooze) {
      // লগইনের সময় দেখালেও একই মিনিটে বারবার নয়
      if (!i.force) {
        final p = await SharedPreferences.getInstance();
        final last = p.getInt('upd_last_shown') ?? 0;
        if (DateTime.now().millisecondsSinceEpoch - last < 60 * 1000) return false;
      }
      return true;
    }
    final p = await SharedPreferences.getInstance();
    final d = p.getString('upd_dismiss');
    if (d == null) return true;
    final parts = d.split('|'); // build|at|millis
    if (parts.length < 3) return true;
    if (parts[0] != '${i.build}' || parts[1] != i.at) return true; // নতুন সংস্করণ বা অ্যাডমিন "আবার জানান" দিয়েছেন
    final ms = int.tryParse(parts[2]) ?? 0;
    return DateTime.now().millisecondsSinceEpoch - ms > 24 * 3600 * 1000;
  }

  /// অ্যাপ খুললে / ফিরে এলে / লগইনের পর: নতুন সংস্করণ থাকলে বার্তা দেখায়
  static Future<void> checkAndShow({bool ignoreSnooze = false}) async {
    if (!ignoreSnooze && DateTime.now().difference(_lastFetch).inMinutes < 10 && available.value == null) return;
    final info = await fetch();
    if (!isNewer(info)) {
      available.value = null;
      return;
    }
    available.value = info;
    if (_sheetOpen) return;
    if (!await _shouldShow(info!, ignoreSnooze: ignoreSnooze)) return;
    final ctx = appNavKey.currentState?.overlay?.context;
    if (ctx == null || !ctx.mounted) return;
    await showSheet(ctx, info);
  }

  static Future<void> showSheet(BuildContext context, UpdateInfo info) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final p = await SharedPreferences.getInstance();
    await p.setInt('upd_last_shown', DateTime.now().millisecondsSinceEpoch);
    if (!context.mounted) {
      _sheetOpen = false;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: !info.force,
      enableDrag: !info.force,
      backgroundColor: Colors.transparent,
      builder: (_) => PopScope(canPop: !info.force, child: _UpdateSheet(info: info)),
    );
    _sheetOpen = false;
  }

  static Future<void> snooze(UpdateInfo i) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('upd_dismiss', '${i.build}|${i.at}|${DateTime.now().millisecondsSinceEpoch}');
  }

  /// ব্যাকগ্রাউন্ডে (অ্যাপ বন্ধ থাকলেও) নতুন সংস্করণ এলে ফোনের নোটিফিকেশন — প্রতি সংস্করণে একবার
  static Future<void> pollAndNotify() async {
    try {
      final info = await fetch();
      if (!isNewer(info)) return;
      final p = await SharedPreferences.getInstance();
      final key = '${info!.build}|${info.at}';
      if (p.getString('upd_notified') == key) return;
      await p.setString('upd_notified', key);
      await SysNotify.showUpdate(
        title: 'নতুন আপডেট এসেছে${info.version.isEmpty ? '' : ' (${info.version})'}',
        body: info.noteLines.isEmpty ? 'আমার সকাল ২৪ অ্যাপের নতুন সংস্করণ এসেছে। আপডেট করে নিন।' : info.noteLines.take(3).join(' • '),
      );
    } catch (_) {}
  }

  /// নোটিফিকেশনে ট্যাপ করলে
  static Future<void> onNotificationTap() async {
    final info = await fetch();
    if (info == null || !isNewer(info)) return;
    available.value = info;
    final ctx = appNavKey.currentState?.overlay?.context;
    if (ctx != null && ctx.mounted) await showSheet(ctx, info);
  }

  /// গুগল ড্রাইভের শেয়ার-লিংককে সরাসরি-ডাউনলোড লিংকে বদলায় (ড্রাইভের "ভাইরাস স্ক্যান" পাতা এড়াতে)।
  /// ড্রাইভের ফাইল "Anyone with the link" করা থাকতে হবে। অন্য লিংক (GitHub Release / নিজের সাইট) যেমন আছে তেমনই।
  static String directUrl(String u) {
    final m = RegExp(r'drive\.google\.com/file/d/([A-Za-z0-9_-]+)').firstMatch(u) ??
        RegExp(r'drive\.google\.com/(?:open|uc)\?[^#]*id=([A-Za-z0-9_-]+)').firstMatch(u);
    if (m != null) return 'https://drive.usercontent.google.com/download?id=${m.group(1)}&export=download&confirm=t';
    return u;
  }

  static Future<void> startUpdate(UpdateInfo i) async {
    final ok = await openExternal(i.url);
    if (!ok) await openLink(i.url);
  }
}

class _UpdateSheet extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  UpdateInfo get info => widget.info;
  bool _busy = false;
  bool _failed = false;
  int _pct = 0;
  String _msg = '';

  void _fail(String m) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = true;
      _msg = m;
    });
  }

  /// অ্যাপের ভেতরেই APK নামিয়ে ফোনের ইনস্টলার খোলে (OtaUpdate)
  Future<void> _install() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _pct = 0;
      _msg = 'ডাউনলোড শুরু হচ্ছে…';
    });
    try {
      final stream = OtaUpdate().execute(UpdateChecker.directUrl(info.url), destinationFilename: 'amarsokal24_update.apk');
      await for (final ev in stream) {
        if (!mounted) return;
        final st = ev.status.toString().split('.').last;
        if (st == 'DOWNLOADING') {
          setState(() {
            _pct = int.tryParse(ev.value ?? '') ?? _pct;
            _msg = 'ডাউনলোড হচ্ছে…';
          });
        } else if (st == 'INSTALLING') {
          setState(() {
            _pct = 100;
            _msg = 'ইনস্টলার খুলেছে — ফোনের "ইনস্টল/আপডেট" বাটনে চাপুন। প্রথমবার "এই উৎস থেকে অনুমতি" চাইলে অনুমতি দিন।';
            _busy = false;
          });
        } else if (st == 'INSTALLATION_DONE') {
          setState(() {
            _busy = false;
            _msg = 'ইনস্টল সম্পন্ন।';
          });
        } else if (st == 'CANCELED') {
          _fail('বাতিল হয়েছে।');
          return;
        } else if (st.contains('ERROR')) {
          _fail(st == 'PERMISSION_NOT_GRANTED_ERROR'
              ? 'ইনস্টলের অনুমতি দেওয়া হয়নি। ফোনের সেটিংসে এই অ্যাপকে "অ্যাপ ইনস্টল করার অনুমতি" দিয়ে আবার চেষ্টা করুন।'
              : 'অ্যাপের ভেতরে ডাউনলোড করা যায়নি। আবার চেষ্টা করুন বা নিচের "ব্রাউজারে ডাউনলোড" চাপুন।');
          return;
        }
      }
      if (mounted && _busy) setState(() => _busy = false);
    } catch (_) {
      _fail('অ্যাপের ভেতরে ডাউনলোড করা যায়নি। আবার চেষ্টা করুন বা নিচের "ব্রাউজারে ডাউনলোড" চাপুন।');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final lines = info.noteLines;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(color: t.colorScheme.surface, borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000B3F), Color(0xFF1B2C85), Color(0xFF45208A)])),
            child: Row(children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(30), border: Border.all(color: Colors.white54, width: 1.5)),
                child: const Icon(Icons.system_update_alt_rounded, color: Color(0xFFFFB300), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('নতুন আপডেট এসেছে', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(34), borderRadius: BorderRadius.circular(12)),
                    child: Text(info.version.isEmpty ? 'সংস্করণ ${bn(info.build)}' : 'সংস্করণ ${bn(info.version)}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  info.force ? 'অ্যাপটি চালিয়ে যেতে আপডেট করা জরুরি।' : 'আরও ভালো অভিজ্ঞতার জন্য অ্যাপটি আপডেট করে নিন।',
                  style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700),
                ),
                if (lines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('যা নতুন:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 6),
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle_rounded, size: 17, color: Color(0xFF16A34A))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l, style: const TextStyle(fontSize: 14.5, height: 1.4))),
                      ]),
                    ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
            child: Column(children: [
              if (_busy || _msg.isNotEmpty) ...[
                if (_busy) LinearProgressIndicator(value: _pct > 0 ? _pct / 100 : null, minHeight: 6, borderRadius: BorderRadius.circular(6)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
                  child: Text(_busy && _pct > 0 ? '$_msg ${bn(_pct)}%' : _msg, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.4, color: _failed ? Colors.red.shade700 : null)),
                ),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: const Color(0xFFFFB300), foregroundColor: const Color(0xFF2B1B00)),
                onPressed: _busy ? null : _install,
                icon: const Icon(Icons.download_rounded),
                label: Text(_busy ? 'নামছে…' : (_failed ? 'আবার চেষ্টা করুন' : 'এখনই আপডেট করুন'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
              ),
              if (_failed)
                TextButton(onPressed: () => UpdateChecker.startUpdate(info), child: const Text('ব্রাউজারে ডাউনলোড')),
              if (!info.force && !_busy)
                TextButton(
                  onPressed: () async {
                    await UpdateChecker.snooze(info);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('পরে মনে করিয়ে দিন'),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
