import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../util.dart';
import '../widgets.dart';
import '../rewards/reward_api.dart';
import '../rewards/reward_screens.dart' show rewardSnack, RewardDashboard, rewardCoin;
import '../update_checker.dart';
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

/// অ্যাডমিন অটো-পাবলিশ চালু রাখলে (প্যানেলের তথ্য থেকে জানা যায়) "যাচাই" নয়, "প্রকাশের জন্য প্রস্তুত হচ্ছে" দেখায়
bool _autoMode = false;

String _stText(String s) {
  switch (s) {
    case 'pending':
      return _autoMode ? 'প্রকাশের জন্য প্রস্তুত হচ্ছে' : 'যাচাইয়ের অপেক্ষায়';
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
  bool _resetAsked = false;
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
        _resetAsked = j['reset_requested'] == true;
      });
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      final m = await RepApi.resetRequest(_code.text.trim());
      if (mounted) setState(() => _resetAsked = true);
      rewardSnack(context, m);
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
        if (_resetAsked)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(14)),
            child: const Text('রিসেটের অনুরোধ অফিসে পাঠানো হয়েছে। অফিস অনুমোদন দিলে "খুঁজুন" দিয়ে নতুন পাসওয়ার্ড তৈরি করতে পারবেন।', style: TextStyle(height: 1.4)),
          )
        else
          TextButton(onPressed: _busy ? null : _reset, child: const Text('পাসওয়ার্ড ভুলে গেছেন? রিসেটের অনুরোধ পাঠান', style: TextStyle(fontWeight: FontWeight.w700))),
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
  Timer? _poll;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    // শেষবারের তথ্য ফোনে/মেমোরিতে থাকে — প্রথম ফ্রেমেই দেখায়, কোনো লোডিং ঘোরে না
    final c = RepApi.panelMem;
    if (c != null) {
      _apply(c);
      _loading = false;
    }
    RepApi.tick.addListener(_load);
    _load();
    RepApi.linkReward(); // রিওয়ার্ড অ্যাকাউন্ট যুক্ত না থাকলে যুক্ত করে
  }

  @override
  void dispose() {
    _poll?.cancel();
    RepApi.tick.removeListener(_load);
    super.dispose();
  }

  void _apply(Map<String, dynamic> j) {
    _me = j;
    final lim = j['limits'] is Map ? Map<String, dynamic>.from(j['limits'] as Map) : <String, dynamic>{};
    _autoMode = lim['auto'] == true;
    final l = j['items'];
    _news = l is List ? l.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  }

  /// প্রক্রিয়াধীন নিউজ থাকলে প্রতি ৮ সেকেন্ডে অবস্থা দেখে (অটো-পাবলিশে কয়েক সেকেন্ডেই "প্রকাশিত" হয়ে যায়)
  void _watch() {
    final busy = _news.any((n) => '${n['status']}' != 'published' && '${n['status']}' != 'rejected');
    if (!busy) {
      _poll?.cancel();
      _poll = null;
      _polls = 0;
      return;
    }
    _poll ??= Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || ++_polls > 45) {
        _poll?.cancel();
        _poll = null;
        return;
      }
      _load();
    });
  }

  Future<void> _load() async {
    try {
      final j = await RepApi.panel();
      if (!mounted) return;
      setState(() {
        _apply(j);
        _err = null;
        _loading = false;
      });
      _watch();
    } on RewardError catch (e) {
      if (mounted) {
        setState(() {
          // তথ্য আগে থেকেই দেখানো থাকলে (ক্যাশ) ত্রুটির লাল বার্তা দিয়ে ভয় দেখাই না
          _err = _me == null ? e.message : null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _newNews() async {
    final limits = _me?['limits'] is Map ? Map<String, dynamic>.from(_me!['limits'] as Map) : <String, dynamic>{};
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RepSubmitScreen(minChars: ri(limits['min_chars']) == 0 ? 200 : ri(limits['min_chars']), auto: limits['auto'] == true),
    ));
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
      if (mounted) rewardSnack(context, 'পাসওয়ার্ড বদলানো হয়েছে।');
    } on RewardError catch (e) {
      if (mounted) rewardSnack(context, e.message);
    }
  }

  Widget _updateCard() {
    return ValueListenableBuilder<UpdateInfo?>(
      valueListenable: UpdateChecker.available,
      builder: (context, u, _) {
        if (u == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => UpdateChecker.showSheet(context, u),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
                boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withAlpha(90), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                const Icon(Icons.system_update_alt_rounded, color: Color(0xFF2B1B00), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('নতুন আপডেট এসেছে', style: TextStyle(color: Color(0xFF2B1B00), fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(u.version.isEmpty ? 'ট্যাপ করে আপডেট করে নিন' : 'সংস্করণ ${bn(u.version)} — ট্যাপ করে আপডেট করুন', style: const TextStyle(color: Color(0xFF2B1B00), fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF2B1B00)),
              ]),
            ),
          ),
        );
      },
    );
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
      body: (_loading && _me == null)
          ? const _RepSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
                if (_err != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Expanded(child: Text(_err!)),
                      TextButton(onPressed: _load, child: const Text('আবার')),
                    ]),
                  ),
                _updateCard(),
                _profile(context),
                const SizedBox(height: 14),
                _stats(context),
                const SizedBox(height: 14),
                _coinCard(context),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), backgroundColor: const Color(0xFFFFB300), foregroundColor: const Color(0xFF2B1B00), elevation: 3, shadowColor: const Color(0xFFFFB300)),
                  onPressed: _newNews,
                  icon: const Icon(Icons.edit_note_rounded, size: 28),
                  label: const Text('নতুন নিউজ পাঠান', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  const Expanded(child: Text('আমার পাঠানো নিউজ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                  if (_news.isNotEmpty) Text('${bn(_news.length)}টি', style: TextStyle(color: cs.outline, fontWeight: FontWeight.w700)),
                ]),
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

  Widget _coinCard(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: RewardApi.me,
      builder: (context, m, _) {
        final linked = RewardApi.loggedIn.value;
        final taka = double.tryParse('${m?['taka'] ?? 0}') ?? 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.amber.withAlpha(34), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.amber.withAlpha(110))),
          child: Row(children: [
            rewardCoin(42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('আমার রিওয়ার্ড কয়েন', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(linked && m != null ? '${bn(ri(m['coins']))} কয়েন (≈ ${bn(taka == taka.roundToDouble() ? '${taka.toInt()}' : taka.toStringAsFixed(2))} টাকা)' : 'রিওয়ার্ড অ্যাকাউন্ট যুক্ত হচ্ছে…', style: const TextStyle(fontSize: 13.5)),
              ]),
            ),
            TextButton(
              onPressed: linked ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardDashboard())) : () => RepApi.linkReward(),
              child: Text(linked ? 'কয়েন ড্যাশবোর্ড' : 'আবার চেষ্টা', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      },
    );
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
      const SizedBox(height: 10),
      Builder(builder: (context) {
        final mx = ri(lim['daily_max']) == 0 ? 10 : ri(lim['daily_max']);
        final used = ri(_me?['today']);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('আজ জমা দিয়েছেন ${bn(used)}টি / সর্বোচ্চ ${bn(mx)}টি', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (used / mx).clamp(0.0, 1.0), minHeight: 6, color: const Color(0xFFFFB300), backgroundColor: Colors.black12)),
        ]);
      }),
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
  final bool auto; // অটো-পাবলিশ চালু থাকলে যাচাই ছাড়াই সরাসরি প্রকাশের জন্য যায়
  const RepSubmitScreen({super.key, required this.minChars, this.auto = false});

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
          child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6)) : Text(widget.auto ? 'প্রকাশের জন্য পাঠান' : 'যাচাইয়ের জন্য পাঠান', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        const SizedBox(height: 8),
        Text(widget.auto ? 'পাঠানোর কিছুক্ষণের মধ্যেই নিউজ সরাসরি প্রকাশ হবে। প্রকাশ হলেই আপনার ফোনে নোটিফিকেশন আসবে।' : 'পাঠানোর পর অফিসে যাচাই হবে। প্রকাশ হলে বা না হলে (কারণসহ) আপনার ফোনে নোটিফিকেশন আসবে।', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, height: 1.4)),
      ]),
    );
  }
}


/// প্যানেলের তথ্য ফোনে না থাকলে (একদম প্রথমবার) ঘুরন্ত গোল চাকার বদলে কাঠামোর ঝিলিক-ধূসর ঘর
class _RepSkeleton extends StatefulWidget {
  const _RepSkeleton();

  @override
  State<_RepSkeleton> createState() => _RepSkeletonState();
}

class _RepSkeletonState extends State<_RepSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final a = 14 + (_c.value * 18).round();
        Widget box(double h, {double r = 18}) => Container(height: h, decoration: BoxDecoration(color: base.withAlpha(a), borderRadius: BorderRadius.circular(r)));
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          children: [
            box(104, r: 24),
            const SizedBox(height: 14),
            Row(children: [Expanded(child: box(74)), const SizedBox(width: 10), Expanded(child: box(74)), const SizedBox(width: 10), Expanded(child: box(74))]),
            const SizedBox(height: 14),
            box(66),
            const SizedBox(height: 14),
            box(58),
            const SizedBox(height: 22),
            box(90),
            const SizedBox(height: 12),
            box(90),
          ],
        );
      },
    );
  }
}
