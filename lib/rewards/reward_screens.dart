import 'dart:math';
import 'package:flutter/material.dart';
import '../config.dart';
import '../util.dart';
import '../rep/rep_api.dart';
import '../rep/rep_screens.dart';
import 'reward_api.dart';

String _dt(dynamic v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return '';
  final d = DateTime.tryParse('${s.replaceFirst(' ', 'T')}Z');
  return d == null ? s : bnDateTime(d.toLocal().toIso8601String());
}

String _taka(dynamic v) {
  final n = double.tryParse('${v ?? 0}') ?? 0;
  return bn(n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(2));
}

String _statusLabel(String s) {
  switch (s) {
    case 'pending':
      return 'যাচাই চলছে';
    case 'approved':
      return 'অনুমোদিত';
    case 'paid':
      return 'পরিশোধ হয়েছে';
    case 'rejected':
      return 'বাতিল';
    case 'cancelled':
      return 'বাতিল';
    default:
      return s;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'approved':
    case 'paid':
      return Colors.green.shade700;
    case 'rejected':
    case 'cancelled':
      return Colors.red.shade700;
    default:
      return Colors.orange.shade800;
  }
}

void rewardSnack(BuildContext c, String m) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}


/// সোনালি কয়েন (ড্যাশবোর্ড, হেডার ও অন্যত্র)
Widget rewardCoin(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE082), Color(0xFFFFA000)]),
        border: Border.all(color: const Color(0xFFFFF3C4), width: size * 0.06),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: size * 0.22, offset: Offset(0, size * 0.08))],
      ),
      child: Icon(Icons.star_rounded, size: size * 0.6, color: const Color(0xFFB26A00)),
    );

/// হেডারের কয়েন-পিল: লগইন না থাকলে "কয়েন জিতুন", থাকলে ব্যালেন্স
class CoinPill extends StatelessWidget {
  const CoinPill({super.key});

  @override
  Widget build(BuildContext context) {
    if (ri(RewardApi.cfg['open']) == 0) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: RepApi.loggedIn,
      builder: (context, _, __) => ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: RewardApi.me,
      builder: (context, me, _) {
        final label = me == null ? (RepApi.loggedIn.value ? 'প্রতিনিধি' : 'কয়েন জিতুন') : '${bn(ri(me['coins']))} কয়েন';
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardScreen())),
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 4, 11, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFB300)]),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                rewardCoin(22),
                const SizedBox(width: 5),
                Text(label, style: const TextStyle(color: Color(0xFF2B1B00), fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
            ),
          ),
        );
      },
      ),
    );
  }
}

/// রিওয়ার্ডের মূল পেজ: লগইন না থাকলে লগইন/রেজিস্টার, থাকলে ড্যাশবোর্ড
class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // প্রতিনিধি লগইন থাকলে প্রতিনিধি প্যানেল; নইলে ইউজারের রিওয়ার্ড (লগইন থাকলে ড্যাশবোর্ড, না থাকলে লগইন পেজ)
    return ValueListenableBuilder<bool>(
      valueListenable: RepApi.loggedIn,
      builder: (context, isRep, _) => isRep
          ? const RepHome()
          : ValueListenableBuilder<bool>(
              valueListenable: RewardApi.loggedIn,
              builder: (context, on, _) => on ? const _Dashboard() : const _AuthView(),
            ),
    );
  }
}

// ---------------------------------------------------------------- লগইন / রেজিস্টার
class _AuthView extends StatefulWidget {
  const _AuthView();

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _reg = false;
  bool _rep = false; // false = ইউজার, true = প্রতিনিধি
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Widget _seg(String t, bool on, VoidCallback f) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: f,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? primary : Colors.transparent, borderRadius: BorderRadius.circular(13)),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: on ? Colors.white : primary)),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    final name = _name.text.trim();
    if (_reg && name.isEmpty) return rewardSnack(context, 'আপনার নাম দিন।');
    if (!email.contains('@')) return rewardSnack(context, 'সঠিক ইমেইল দিন।');
    if (pass.length < 6) return rewardSnack(context, 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।');
    setState(() => _busy = true);
    try {
      if (_reg) {
        await RewardApi.register(name, email, pass);
      } else {
        await RewardApi.login(email, pass);
      }
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = RewardApi.cfg;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('রিওয়ার্ড কয়েন')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000B3F), Color(0xFF1B2C85), Color(0xFF45208A)]),
            boxShadow: [BoxShadow(color: AppConfig.brand.withAlpha(90), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: Column(children: [
            rewardCoin(70),
            const SizedBox(height: 14),
            const Text('খবর পড়ুন, কয়েন জিতুন!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              '${bn(ri(cfg['read_seconds']))} সেকেন্ড খবর পড়লে ${bn(ri(cfg['read_coin']))} কয়েন, ফেসবুকে শেয়ার করলে ${bn(ri(cfg['share_coin']))} কয়েন। '
              '${bn(ri(cfg['coins_per_taka']))} কয়েন = ১ টাকা, বিকাশে তুলুন।',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: primary.withAlpha(20), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(child: _seg('ইউজার', !_rep, () => setState(() => _rep = false))),
            Expanded(child: _seg('প্রতিনিধি', _rep, () => setState(() => _rep = true))),
          ]),
        ),
        const SizedBox(height: 16),
        if (_rep) const RepLoginForm() else ...[
          if (_reg) ...[
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'আপনার নাম', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
            const SizedBox(height: 12),
          ],
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'ইমেইল', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'পাসওয়ার্ড',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : Text(_reg ? 'অ্যাকাউন্ট খুলুন' : 'লগইন করুন'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _reg = !_reg),
            child: Text(_reg ? 'আগেই অ্যাকাউন্ট আছে? লগইন করুন' : 'নতুন? অ্যাকাউন্ট খুলুন', style: TextStyle(color: primary)),
          ),
          if (!_reg)
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ForgotScreen(email: _email.text.trim()))),
              child: const Text('পাসওয়ার্ড ভুলে গেছেন?', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          if (ri(cfg['open']) == 0) ...[
            const SizedBox(height: 8),
            Text('রিওয়ার্ড সিস্টেম এখন বন্ধ আছে।', textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
          ],
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- ড্যাশবোর্ড
/// প্রতিনিধিও (নিজের যুক্ত রিওয়ার্ড অ্যাকাউন্টে) এই ড্যাশবোর্ড দেখেন
class RewardDashboard extends StatelessWidget {
  const RewardDashboard({super.key});

  @override
  Widget build(BuildContext context) => const _Dashboard();
}

class _Dashboard extends StatefulWidget {
  const _Dashboard();

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  String? _err;
  bool _busy = false;
  bool _ckBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _checkin() async {
    setState(() => _ckBusy = true);
    try {
      final j = await RewardApi.checkin();
      final earned = ri(j['earned']);
      final bonus = ri(j['bonus']);
      rewardSnack(context, earned > 0 ? '+${bn(earned)} কয়েন পেয়েছেন${bonus > 0 ? ' (টানা ৭ দিনের বোনাসসহ)' : ''}' : 'আজকের চেক-ইন আগেই হয়ে গেছে।');
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _ckBusy = false);
    }
  }

  Widget _checkinCard(BuildContext context, Map<String, dynamic> m) {
    final ck = m['checkin'] is Map ? Map<String, dynamic>.from(m['checkin'] as Map) : null;
    if (ck == null || ri(ck['on']) != 1) return const SizedBox.shrink();
    final done = ri(ck['done_today']) == 1;
    final streak = ri(ck['streak']);
    final cyc = streak % 7;
    final filled = done ? (cyc == 0 ? 7 : cyc) : cyc;
    final coin = ri(ck['coin']);
    final bonus = ri(ck['bonus']);
    final primary = Theme.of(context).colorScheme.primary;
    return _card(
      context,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('দৈনিক চেক-ইন', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
          Text('টানা ${bn(streak)} দিন', style: TextStyle(fontWeight: FontWeight.w800, color: primary)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 7; i++)
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: i < filled ? const Color(0xFFFFB300) : primary.withAlpha(22), border: i == 6 ? Border.all(color: const Color(0xFFFFB300), width: 2) : null),
              child: Text(bn(i + 1), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: i < filled ? const Color(0xFF2B1B00) : null)),
            ),
        ]),
        const SizedBox(height: 10),
        Text(bonus > 0 ? 'রোজ ${bn(coin)} কয়েন। টানা ৭ দিন হলে ${bn(bonus)} কয়েন বাড়তি বোনাস (আর ${bn(ri(ck['bonus_in_days']))} দিন)।' : 'রোজ ${bn(coin)} কয়েন।', style: const TextStyle(height: 1.4)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: (done || _ckBusy) ? null : _checkin,
          child: _ckBusy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
              : Text(done ? 'আজকের চেক-ইন সম্পন্ন' : 'চেক-ইন করুন (+${bn(coin)} কয়েন)', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Future<void> _load() async {
    try {
      await RewardApi.refreshMe();
      if (mounted) setState(() => _err = null);
    } on RewardError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
  }

  void _history() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardHistoryScreen()));

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
      rewardSnack(context, await RewardApi.changePassword(o.text, n.text));
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    }
  }

  Future<void> _withdraw(Map<String, dynamic> m, Map<String, dynamic> cfg) async {
    final cpt = max(1, ri(cfg['coins_per_taka']));
    final coins = ri(m['coins']);
    final payCoins = coins - coins % cpt;
    final payTaka = payCoins ~/ cpt;
    final user = m['user'] is Map ? Map<String, dynamic>.from(m['user'] as Map) : <String, dynamic>{};
    final ctl = TextEditingController(text: '${user['bkash'] ?? ''}');
    final no = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('বিকাশে টাকা তুলুন'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withAlpha(40), borderRadius: BorderRadius.circular(14)),
            child: Text('${bn(payCoins)} কয়েন = ${bn(payTaka)} টাকা', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctl,
            keyboardType: TextInputType.phone,
            maxLength: 14,
            decoration: const InputDecoration(labelText: 'বিকাশ নম্বর', hintText: '017XXXXXXXX', border: OutlineInputBorder(), counterText: ''),
          ),
          const SizedBox(height: 10),
          const Text('সব কয়েন একসাথে তোলা হবে। রিকোয়েস্ট জমা হলে কয়েন কেটে নেওয়া হবে; অ্যাডমিন যাচাই করে বিকাশে টাকা পাঠাবেন।', style: TextStyle(fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('রিকোয়েস্ট পাঠান')),
        ],
      ),
    );
    if (no == null || no.isEmpty) return;
    setState(() => _busy = true);
    try {
      final j = await RewardApi.withdraw(no);
      rewardSnack(context, '${j['message'] ?? 'রিকোয়েস্ট জমা হয়েছে।'}');
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('রিওয়ার্ড কয়েন'),
        actions: [
          TextButton(onPressed: _history, child: const Text('স্টেটমেন্ট', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          const SizedBox(width: 6),
        ],
      ),
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: RewardApi.me,
        builder: (context, m, _) {
          if (m == null) {
            if (_err == null) return const Center(child: CircularProgressIndicator());
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.all(16), child: Text(_err!, textAlign: TextAlign.center)),
                FilledButton(onPressed: _load, child: const Text('আবার চেষ্টা করুন')),
              ]),
            );
          }
          return RefreshIndicator(onRefresh: _load, child: _body(context, m));
        },
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.colorScheme.outlineVariant.withAlpha(120)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }

  Widget _bar(String label, String right, double p, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          Text(right, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: p.clamp(0.0, 1.0).toDouble(), minHeight: 10, color: color, backgroundColor: color.withAlpha(30)),
        ),
      ]),
    );
  }

  Widget _rule(IconData i, Color c, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.withAlpha(30), shape: BoxShape.circle),
            child: Icon(i, size: 20, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(t, style: const TextStyle(height: 1.4)))),
        ]),
      );

  Widget _body(BuildContext context, Map<String, dynamic> m) {
    final cfg = m['config'] is Map ? Map<String, dynamic>.from(m['config'] as Map) : RewardApi.cfg;
    final user = m['user'] is Map ? Map<String, dynamic>.from(m['user'] as Map) : <String, dynamic>{};
    final wd = m['withdrawal'] is Map ? Map<String, dynamic>.from(m['withdrawal'] as Map) : null;
    final coins = ri(m['coins']);
    final pend = ri(m['pending_coins']);
    final minCoins = ri(m['min_coins']);
    final open = ri(cfg['open']) != 0;
    final notice = '${cfg['notice'] ?? ''}'.trim();
    final readMax = ri(cfg['read_daily_max']);
    final shareMax = ri(cfg['share_daily_max']);
    final readToday = ri(m['today_read']);
    final sharesToday = ri(m['shares_today']);
    final canWithdraw = wd == null && open && coins > 0 && coins >= minCoins;

    String wdLabel;
    if (wd != null) {
      wdLabel = 'উত্তোলন চলমান';
    } else if (canWithdraw) {
      wdLabel = 'বিকাশে টাকা তুলুন';
    } else {
      wdLabel = 'আরও ${bn(max(0, minCoins - coins))} কয়েন লাগবে';
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
      if (!open)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(14)),
          child: const Text('রিওয়ার্ড সিস্টেম এখন সাময়িক বন্ধ আছে।'),
        ),
      if (notice.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.withAlpha(45), borderRadius: BorderRadius.circular(14)),
          child: Text(notice, style: const TextStyle(height: 1.4)),
        ),
      // ব্যালেন্স কার্ড
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000B3F), Color(0xFF1B2C85), Color(0xFF45208A)]),
          boxShadow: [BoxShadow(color: AppConfig.brand.withAlpha(100), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        child: Stack(children: [
          Positioned(right: -34, top: -34, child: _circle(150, Colors.white.withAlpha(16))),
          Positioned(left: -26, bottom: -50, child: _circle(130, Colors.amber.withAlpha(26))),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('স্বাগতম, ${user['name'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                rewardCoin(52),
                const SizedBox(width: 14),
                Text(bn(coins), style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.w800, height: 1)),
                const SizedBox(width: 8),
                const Padding(padding: EdgeInsets.only(top: 18), child: Text('কয়েন', style: TextStyle(color: Colors.white, fontSize: 18))),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withAlpha(32), borderRadius: BorderRadius.circular(22)),
                child: Text('সমপরিমাণ ${_taka(m['taka'])} টাকা', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (pend > 0) ...[
                const SizedBox(height: 10),
                Text('যাচাইয়ের অপেক্ষায় শেয়ার: ${bn(pend)} কয়েন', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      // বাটন: টাকা তোলা ও স্টেটমেন্ট (আইকন নয়, পরিষ্কার লেখা)
      Row(children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB300), foregroundColor: const Color(0xFF2B1B00), minimumSize: const Size.fromHeight(54)),
            onPressed: (_busy || !canWithdraw) ? null : () => _withdraw(m, cfg),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Text(wdLabel, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _history,
            child: const Text('স্টেটমেন্ট ও ইতিহাস', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _checkinCard(context, m),
      if (wd != null)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _statusColor('${wd['status']}').withAlpha(26), borderRadius: BorderRadius.circular(18), border: Border.all(color: _statusColor('${wd['status']}').withAlpha(80))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('চলমান উত্তোলন: ${_taka(wd['taka'])} টাকা', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text('অবস্থা: ${_statusLabel('${wd['status']}')}', style: TextStyle(color: _statusColor('${wd['status']}'), fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('বিকাশ ${wd['bkash'] ?? ''} • ${_dt(wd['created'])}', style: const TextStyle(fontSize: 13)),
          ]),
        ),
      // আজকের অগ্রগতি
      _card(
        context,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('আজকের অগ্রগতি', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 14),
          _bar('খবর পড়ে কয়েন', '${bn(readToday)} / ${bn(readMax)}', readMax <= 0 ? 0 : readToday / readMax, Theme.of(context).colorScheme.primary),
          _bar('ফেসবুক শেয়ার জমা', '${bn(sharesToday)} / ${bn(shareMax)}', shareMax <= 0 ? 0 : sharesToday / shareMax, Colors.green.shade600),
        ]),
      ),
      // নিয়ম
      _card(
        context,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('কীভাবে কয়েন পাবেন', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 8),
          _rule(Icons.menu_book_outlined, Colors.blue.shade700, 'যেকোনো খবর খুলে ${bn(ri(cfg['read_seconds']))} সেকেন্ড পড়লে ${bn(ri(cfg['read_coin']))} কয়েন (দিনে সর্বোচ্চ ${bn(readMax)} কয়েন)'),
          _rule(Icons.play_circle_outline_rounded, Colors.deepOrange.shade600, 'বড়ো ভিডিও পুরোটা দেখলে ${bn(ri(cfg['video_coin']))} কয়েন (দিনে সর্বোচ্চ ${bn(ri(cfg['video_daily_max']))}টি ভিডিও)'),
          _rule(Icons.movie_filter_outlined, Colors.purple.shade600, 'রিলস দেখলে প্রতিটিতে ${bn(ri(cfg['reel_coin']))} পয়েন্ট (দিনে সর্বোচ্চ ${bn(ri(cfg['reel_daily_max']))}টি)'),
          _rule(Icons.newspaper_rounded, Colors.teal.shade600, 'প্রতিনিধির নিউজ পাবলিশ হলে প্রতিটিতে ${bn(ri(cfg['rep_news_coin']))} কয়েন'),
          _rule(Icons.share_outlined, Colors.green.shade700, 'ফেসবুকে শেয়ার করে স্ক্রিনশট জমা দিলে ${bn(ri(cfg['share_coin']))} কয়েন (অ্যাডমিন যাচাইয়ের পর)'),
          _rule(Icons.account_balance_wallet_outlined, Colors.pink.shade600, '${bn(ri(cfg['coins_per_taka']))} কয়েন = ১ টাকা। ন্যূনতম ${bn(ri(cfg['min_withdraw']))} টাকা হলে বিকাশে তুলতে পারবেন'),
        ]),
      ),
      // প্রতিনিধির রিওয়ার্ড অ্যাকাউন্ট প্রতিনিধি প্যানেলের লগইনের সাথে যুক্ত — পাসওয়ার্ড/লগআউট সেখান থেকে
      if (!RepApi.loggedIn.value)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: _changePass, child: const Text('পাসওয়ার্ড বদলান', style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton(
            onPressed: () => RewardApi.logout(),
            child: Text('লগআউট', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
          ),
        ]),
    ]);
  }

  Widget _circle(double d, Color c) => Container(width: d, height: d, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ---------------------------------------------------------------- ইতিহাস
class RewardHistoryScreen extends StatelessWidget {
  const RewardHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('স্টেটমেন্ট ও ইতিহাস'),
          bottom: const TabBar(tabs: [Tab(text: 'কয়েনের হিসাব'), Tab(text: 'শেয়ারের অবস্থা'), Tab(text: 'টাকা তোলা')]),
        ),
        body: TabBarView(children: [
          _HistoryList(loader: RewardApi.ledger, tile: _ledgerTile, empty: 'এখনো কোনো কয়েন যোগ হয়নি।'),
          _HistoryList(loader: RewardApi.shares, tile: _shareTile, empty: 'এখনো কোনো শেয়ার জমা দেননি।'),
          _HistoryList(loader: RewardApi.withdrawals, tile: _wdTile, empty: 'এখনো কোনো উত্তোলনের রিকোয়েস্ট নেই।'),
        ]),
      ),
    );
  }

  static Widget _ledgerTile(Map<String, dynamic> r) {
    final c = ri(r['coins']);
    final type = '${r['type']}';
    final icon = type == 'read' ? Icons.menu_book_outlined : (type == 'share' ? Icons.share_outlined : (type == 'withdraw' ? Icons.account_balance_wallet_outlined : Icons.monetization_on_outlined));
    final note = '${r['note'] ?? ''}'.trim();
    return ListTile(
      leading: Icon(icon),
      title: Text(note.isEmpty ? type : note),
      subtitle: Text(_dt(r['created'])),
      trailing: Text('${c >= 0 ? '+' : '-'}${bn(c.abs())}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
    );
  }

  static Widget _shareTile(Map<String, dynamic> r) {
    final st = '${r['status']}';
    final note = '${r['note'] ?? ''}'.trim();
    return ListTile(
      title: Text('${r['title'] ?? 'নিউজ #${r['post_id']}'}', maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text([_dt(r['created']), if (note.isNotEmpty) note].join('\n')),
      isThreeLine: note.isNotEmpty,
      trailing: Text(_statusLabel(st), style: TextStyle(color: _statusColor(st), fontWeight: FontWeight.bold)),
    );
  }

  static Widget _wdTile(Map<String, dynamic> r) {
    final st = '${r['status']}';
    final extra = ['${r['txn'] ?? ''}'.trim(), '${r['note'] ?? ''}'.trim()].where((e) => e.isNotEmpty).join(' • ');
    return ListTile(
      title: Text('${_taka(r['taka'])} টাকা (${bn(ri(r['coins']))} কয়েন)'),
      subtitle: Text(['বিকাশ ${r['bkash'] ?? ''}', _dt(r['created']), if (extra.isNotEmpty) extra].join('\n')),
      isThreeLine: true,
      trailing: Text(_statusLabel(st), style: TextStyle(color: _statusColor(st), fontWeight: FontWeight.bold)),
    );
  }
}

class _HistoryList extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() loader;
  final Widget Function(Map<String, dynamic>) tile;
  final String empty;
  const _HistoryList({required this.loader, required this.tile, required this.empty});

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _f = widget.loader();

  @override
  bool get wantKeepAlive => true;

  Future<void> _reload() async {
    setState(() => _f = widget.loader());
    try {
      await _f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${snap.error}'),
              TextButton(onPressed: _reload, child: const Text('আবার চেষ্টা করুন')),
            ]),
          );
        }
        final items = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: _reload,
          child: items.isEmpty
              ? ListView(children: [SizedBox(height: 200, child: Center(child: Text(widget.empty)))])
              : ListView.separated(itemCount: items.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) => widget.tile(items[i])),
        );
      },
    );
  }
}


// ---------------------------------------------------------------- ইউজার: পাসওয়ার্ড ভুলে গেলে রিসেট (ইমেইলে কোড)
class _ForgotScreen extends StatefulWidget {
  final String email;
  const _ForgotScreen({required this.email});

  @override
  State<_ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<_ForgotScreen> {
  late final TextEditingController _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _pass = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String _info = '';

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_email.text.contains('@')) return rewardSnack(context, 'সঠিক ইমেইল দিন।');
    setState(() => _busy = true);
    try {
      final m = await RewardApi.forgot(_email.text.trim());
      if (mounted) {
        setState(() {
          _sent = true;
          _info = m;
        });
      }
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_code.text.trim().length != 6) return rewardSnack(context, 'ইমেইলে পাওয়া ৬ অঙ্কের কোড দিন।');
    if (_pass.text.length < 6) return rewardSnack(context, 'নতুন পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের দিন।');
    setState(() => _busy = true);
    try {
      final m = await RewardApi.resetPassword(_email.text.trim(), _code.text.trim(), _pass.text);
      if (!mounted) return;
      rewardSnack(context, m);
      Navigator.of(context).pop();
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('পাসওয়ার্ড রিসেট')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('আপনার রিওয়ার্ড অ্যাকাউন্টের ইমেইল দিন। সেই ইমেইলে একটি ৬ অঙ্কের কোড যাবে।', style: TextStyle(height: 1.45)),
        const SizedBox(height: 14),
        TextField(controller: _email, enabled: !_sent, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'ইমেইল', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
        const SizedBox(height: 14),
        if (!_sent)
          FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Text('কোড পাঠান'),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.withAlpha(25), borderRadius: BorderRadius.circular(14)),
            child: Text(_info, style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 14),
          TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '৬ অঙ্কের কোড', prefixIcon: Icon(Icons.pin_outlined), border: OutlineInputBorder(), counterText: '')),
          const SizedBox(height: 12),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _reset,
            child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Text('পাসওয়ার্ড বদলান'),
          ),
          TextButton(onPressed: _busy ? null : () => setState(() => _sent = false), child: const Text('আবার কোড চান / ইমেইল বদলান')),
        ],
      ]),
    );
  }
}
