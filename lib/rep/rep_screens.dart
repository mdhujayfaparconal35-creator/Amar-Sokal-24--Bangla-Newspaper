import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../util.dart';
import '../widgets.dart';
import '../rewards/reward_api.dart' show RewardError, ri;
import '../rewards/reward_screens.dart' show rewardSnack;
import 'rep_api.dart';

Color _stColor(String s) {
  switch (s) {
    case 'published':
      return Colors.green.shade700;
    case 'rejected':
      return Colors.red.shade700;
    default:
      return Colors.orange.shade800;
  }
}

String _stText(String s) {
  switch (s) {
    case 'pending':
      return 'যাচাইয়ের অপেক্ষায়';
    case 'published':
      return 'প্রকাশিত';
    case 'rejected':
      return 'প্রকাশ হয়নি';
    default:
      return 'প্রকাশের প্রক্রিয়ায়';
  }
}

/// প্রতিনিধি লগইনের ফর্ম (লগইন পেজের "প্রতিনিধি" অপশনে)।
/// ধাপ ১: ডাটাবেজ নাম্বার দিয়ে "খুঁজুন" → প্রতিনিধির তথ্য (নাম, পদবি, ছবি) আসে
/// ধাপ ২: আগে পাসওয়ার্ড তৈরি না থাকলে নিজে পাসওয়ার্ড তৈরি করবেন; থাকলে পাসওয়ার্ড দিয়ে লগইন
class RepLoginForm extends StatefulWidget {
  const RepLoginForm({super.key});

  @override
  State<RepLoginForm> createState() => _RepLoginFormState();
}

class _RepLoginFormState extends State<RepLoginForm> {
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  Map<String, dynamic>? _rep; // ধাপ ২-এ প্রতিনিধির তথ্য
  bool _has = false; // পাসওয়ার্ড আগেই তৈরি আছে কি না
  String _status = 'none';
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _code.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _back() => setState(() {
        _rep = null;
        _pass.clear();
        _pass2.clear();
      });

  Future<void> _find() async {
    if (_code.text.trim().isEmpty) return rewardSnack(context, 'ডাটাবেজ নাম্বার দিন (যেমন AS24-39)।');
    setState(() => _busy = true);
    try {
      final j = await RepApi.lookup(_code.text.trim());
      if (!mounted) return;
      setState(() {
        _rep = j['rep'] is Map ? Map<String, dynamic>.from(j['rep'] as Map) : <String, dynamic>{};
        _has = j['has_password'] == true;
        _status = '${j['status'] ?? 'none'}';
      });
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (_pass.text.isEmpty) return rewardSnack(context, 'পাসওয়ার্ড দিন।');
    setState(() => _busy = true);
    try {
      await RepApi.login(_code.text.trim(), _pass.text);
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_pass.text.length < 6) return rewardSnack(context, 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের দিন।');
    if (_pass.text != _pass2.text) return rewardSnack(context, 'দুইবারের পাসওয়ার্ড মিলছে না।');
    setState(() => _busy = true);
    try {
      final j = await RepApi.setup(_code.text.trim(), _pass.text);
      if (j['pending'] == true && mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.hourglass_top, size: 40),
            content: Text('${j['msg'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('ঠিক আছে'))],
          ),
        );
        if (mounted) _back();
      }
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _profile() {
    final r = _rep ?? <String, dynamic>{};
    final photo = '${r['photo'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000B3F), Color(0xFF1B2C85), Color(0xFF45208A)]),
      ),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), color: Colors.white24),
          child: ClipOval(
            child: photo.startsWith('http')
                ? Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 34))
                : const Icon(Icons.person, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            if ('${r['designation'] ?? ''}'.isNotEmpty) Text('${r['designation']}', style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
            const SizedBox(height: 4),
            Text('ডাটাবেজ নাম্বার: ${r['code'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _passField(TextEditingController c, String label, {bool submit = false}) => TextField(
        controller: c,
        obscureText: _hide,
        onSubmitted: submit ? (_) => (_has ? _login() : _create()) : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // ---- ধাপ ১: ডাটাবেজ নাম্বার
    if (_rep == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          onSubmitted: (_) => _find(),
          decoration: const InputDecoration(labelText: 'ডাটাবেজ নাম্বার', hintText: 'AS24-39 অথবা 39', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _find,
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Text('খুঁজুন'),
        ),
        const SizedBox(height: 10),
        const Text('আপনার প্রতিনিধি ডাটাবেজ নাম্বার দিন। প্রথমবার হলে এরপর নিজের পাসওয়ার্ড তৈরি করতে পারবেন।', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.4)),
      ]);
    }
    // ---- ধাপ ২: তথ্য দেখিয়ে লগইন বা পাসওয়ার্ড তৈরি
    final blocked = _has && (_status == 'blocked');
    final pending = _has && (_status == 'pending');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _profile(),
      const SizedBox(height: 14),
      if (blocked || pending)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(14)),
          child: Text(blocked ? 'আপনার অ্যাপ-অ্যাকাউন্ট বন্ধ আছে। অফিসে যোগাযোগ করুন।' : 'আপনার অ্যাকাউন্ট অফিসের অনুমোদনের অপেক্ষায় আছে। চালু হলে পাসওয়ার্ড দিয়ে ঢুকতে পারবেন।', style: const TextStyle(height: 1.4)),
        )
      else if (_has) ...[
        _passField(_pass, 'পাসওয়ার্ড', submit: true),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _login,
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Text('লগইন'),
        ),
        const SizedBox(height: 8),
        const Text('পাসওয়ার্ড ভুলে গেলে অফিসে যোগাযোগ করুন, রিসেট করে দেওয়া হবে।', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, height: 1.4)),
      ] else ...[
        const Text('এটাই আপনি? তাহলে নিজের জন্য একটি পাসওয়ার্ড তৈরি করুন। এটি মনে রাখবেন, পরে এই পাসওয়ার্ড দিয়েই ঢুকবেন।', style: TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _passField(_pass, 'নতুন পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)'),
        const SizedBox(height: 12),
        _passField(_pass2, 'আবার পাসওয়ার্ড লিখুন', submit: true),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Text('পাসওয়ার্ড তৈরি করে ঢুকুন'),
        ),
      ],
      const SizedBox(height: 4),
      TextButton(onPressed: _busy ? null : _back, child: const Text('আমি নই / অন্য নাম্বার দিন')),
    ]);
  }
}

// ---------------------------------------------------------------- প্রতিনিধি প্যানেল
class RepHome extends StatefulWidget {
  const RepHome({super.key});

  @override
  State<RepHome> createState() => _RepHomeState();
}

class _RepHomeState extends State<RepHome> {
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _news = [];
  String? _err;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    RepApi.tick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    RepApi.tick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await RepApi.me();
      final n = await RepApi.myNews();
      if (!mounted) return;
      setState(() {
        _me = m;
        _news = n;
        _err = null;
        _loading = false;
      });
    } on RewardError catch (e) {
      if (mounted) {
        setState(() {
          _err = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _newNews() async {
    final limits = _me?['limits'] is Map ? Map<String, dynamic>.from(_me!['limits'] as Map) : <String, dynamic>{};
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RepSubmitScreen(minChars: ri(limits['min_chars']) == 0 ? 200 : ri(limits['min_chars']))));
    if (sent == true) _load();
  }

  Future<void> _changePass() async {
    final o = TextEditingController();
    final n = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('পাসওয়ার্ড বদলান'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: o, obscureText: true, decoration: const InputDecoration(labelText: 'বর্তমান পাসওয়ার্ড')),
          const SizedBox(height: 8),
          TextField(controller: n, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('বদলান')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await RepApi.changePassword(o.text, n.text);
      rewardSnack(context, 'পাসওয়ার্ড বদলানো হয়েছে।');
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('প্রতিনিধি প্যানেল'),
        actions: [
          TextButton(onPressed: _changePass, child: const Text('পাসওয়ার্ড বদল', style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
                if (_err != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(14)),
                    child: Text(_err!),
                  ),
                _profile(context),
                const SizedBox(height: 14),
                _stats(context),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: const Color(0xFFFFB300), foregroundColor: const Color(0xFF2B1B00)),
                  onPressed: _newNews,
                  child: const Text('নতুন নিউজ পাঠান', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
                const SizedBox(height: 22),
                const Text('আমার পাঠানো নিউজ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 8),
                if (_news.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('এখনো কোনো নিউজ পাঠাননি।', style: TextStyle(color: cs.outline))),
                  ),
                for (final n in _news) _newsTile(context, n),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => RepApi.logout(),
                    child: Text('লগআউট', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _profile(BuildContext context) {
    final r = RepApi.rep.value ?? <String, dynamic>{};
    final photo = '${r['photo'] ?? ''}';
    final expired = r['expired'] == true;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000B3F), Color(0xFF1B2C85), Color(0xFF45208A)]),
        ),
        child: Row(children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), color: Colors.white24),
            child: ClipOval(
              child: photo.startsWith('http')
                  ? Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 38))
                  : const Icon(Icons.person, color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              if ('${r['designation'] ?? ''}'.isNotEmpty) Text('${r['designation']}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withAlpha(32), borderRadius: BorderRadius.circular(14)),
                child: Text('ডাটাবেজ নাম্বার: ${r['code'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
      if (expired)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(14)),
          child: const Text('আপনার প্রতিনিধি কার্ডের মেয়াদ শেষ হয়েছে। অফিসে যোগাযোগ করে নবায়ন করুন।'),
        ),
    ]);
  }

  Widget _stats(BuildContext context) {
    final c = _me?['counts'] is Map ? Map<String, dynamic>.from(_me!['counts'] as Map) : <String, dynamic>{};
    final lim = _me?['limits'] is Map ? Map<String, dynamic>.from(_me!['limits'] as Map) : <String, dynamic>{};
    Widget box(String label, int v, Color col) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: col.withAlpha(24), borderRadius: BorderRadius.circular(16), border: Border.all(color: col.withAlpha(70))),
            child: Column(children: [
              Text(bn(v), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: col)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        box('যাচাইয়ের অপেক্ষায়', ri(c['pending']), Colors.orange.shade800),
        const SizedBox(width: 10),
        box('প্রকাশিত', ri(c['published']), Colors.green.shade700),
        const SizedBox(width: 10),
        box('প্রকাশ হয়নি', ri(c['rejected']), Colors.red.shade700),
      ]),
      const SizedBox(height: 8),
      Text('আজ জমা দিয়েছেন ${bn(ri(_me?['today']))}টি / সর্বোচ্চ ${bn(ri(lim['daily_max']) == 0 ? 10 : ri(lim['daily_max']))}টি', style: const TextStyle(fontSize: 13.5)),
    ]);
  }

  Widget _newsTile(BuildContext context, Map<String, dynamic> n) {
    final st = '${n['status']}';
    final col = _stColor(st);
    final img = '${n['image'] ?? ''}';
    final reason = '${n['reason'] ?? ''}'.trim();
    final url = '${n['url'] ?? ''}';
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.colorScheme.outlineVariant.withAlpha(120)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (img.startsWith('http'))
            ClipRRect(borderRadius: BorderRadius.circular(10), child: NetImage(img, width: 78, height: 78, fit: BoxFit.cover)),
          if (img.startsWith('http')) const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n['title'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.3)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: col.withAlpha(28), borderRadius: BorderRadius.circular(12)),
                  child: Text(_stText(st), style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(bnDateTime('${n['created'] ?? ''}'), style: TextStyle(fontSize: 12, color: t.colorScheme.outline), overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
        ]),
        if (st == 'rejected' && reason.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withAlpha(22), borderRadius: BorderRadius.circular(12)),
            child: Text('কারণ: $reason', style: const TextStyle(height: 1.4)),
          ),
        if (st == 'published' && url.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => openLink(url), child: const Text('প্রকাশিত নিউজ দেখুন', style: TextStyle(fontWeight: FontWeight.w800))),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- নিউজ জমা
class RepSubmitScreen extends StatefulWidget {
  final int minChars;
  const RepSubmitScreen({super.key, required this.minChars});

  @override
  State<RepSubmitScreen> createState() => _RepSubmitScreenState();
}

class _RepSubmitScreenState extends State<RepSubmitScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final String _uid = RepApi.randomId(); // নেট-সমস্যায় আবার চাপলে একই নিউজ দুবার জমা হয় না
  List<String> _cats = [];
  String _cat = '';
  String? _img;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
    RepApi.categories().then((c) {
      if (mounted) setState(() => _cats = c);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _ok => _title.text.trim().length >= 10 && _body.text.trim().length >= widget.minChars && _img != null;

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85);
      if (x == null) return;
      if (await x.length() > 7 * 1024 * 1024) return rewardSnack(context, 'ছবি সর্বোচ্চ ৭ MB হতে পারবে।');
      setState(() => _img = x.path);
    } catch (_) {
      rewardSnack(context, 'ছবি নেওয়া যায়নি।');
    }
  }

  Future<void> _send() async {
    if (!_ok || _busy) return;
    setState(() => _busy = true);
    try {
      final j = await RepApi.submit(title: _title.text.trim(), body: _body.text.trim(), category: _cat, imagePath: _img!, uid: _uid);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 46),
          content: Text('${j['msg'] ?? 'নিউজ জমা হয়েছে।'}', textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('ঠিক আছে'))],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _body.text.trim().length;
    final enough = n >= widget.minChars;
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন নিউজ পাঠান')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _title,
          maxLength: 220,
          maxLines: null,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'শিরোনাম', hintText: 'নিউজের শিরোনাম লিখুন', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _body,
          minLines: 9,
          maxLines: 30,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(labelText: 'বিস্তারিত নিউজ', hintText: 'কী, কোথায়, কখন, কে, কেন — সব তথ্যসহ লিখুন', alignLabelWithHint: true, border: OutlineInputBorder()),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text('${bn(n)} / কমপক্ষে ${bn(widget.minChars)} অক্ষর', style: TextStyle(fontWeight: FontWeight.w700, color: enough ? Colors.green.shade700 : Colors.orange.shade800)),
        ),
        if (_cats.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: _cat.isEmpty ? null : _cat,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'ক্যাটাগরি (ঐচ্ছিক)', border: OutlineInputBorder()),
            items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _cat = v ?? ''),
          ),
          const SizedBox(height: 14),
        ],
        const Text('নিউজের ছবি (বাধ্যতামূলক)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        const SizedBox(height: 8),
        if (_img != null)
          ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(_img!), height: 190, width: double.infinity, fit: BoxFit.cover)),
        if (_img != null) const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _pick(ImageSource.gallery), child: Text(_img == null ? 'গ্যালারি থেকে' : 'ছবি বদলান'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _pick(ImageSource.camera), child: const Text('ক্যামেরায় তুলুন'))),
        ]),
        const SizedBox(height: 6),
        const Text('ছবি পরিষ্কার ও নিউজের সাথে মিল থাকতে হবে।', style: TextStyle(fontSize: 12.5)),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: (_ok && !_busy) ? _send : null,
          child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6)) : const Text('যাচাইয়ের জন্য পাঠান', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        const SizedBox(height: 8),
        const Text('পাঠানোর পর অফিসে যাচাই হবে। প্রকাশ হলে বা না হলে (কারণসহ) আপনার ফোনে নোটিফিকেশন আসবে।', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, height: 1.4)),
      ]),
    );
  }
}
