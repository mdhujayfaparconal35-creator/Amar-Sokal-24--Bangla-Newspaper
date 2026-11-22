import 'dart:math';
import 'package:flutter/material.dart';
import '../config.dart';
import '../util.dart';
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

/// রিওয়ার্ডের মূল পেজ: লগইন না থাকলে লগইন/রেজিস্টার, থাকলে ড্যাশবোর্ড
class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: RewardApi.loggedIn,
      builder: (context, on, _) => on ? const _Dashboard() : const _AuthView(),
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
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
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
        Icon(Icons.monetization_on_rounded, size: 72, color: Colors.amber.shade700),
        const SizedBox(height: 10),
        Text('খবর পড়ুন, কয়েন জিতুন!',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          '${bn(ri(cfg['read_seconds']))} সেকেন্ড খবর পড়লে ${bn(ri(cfg['read_coin']))} কয়েন, ফেসবুকে শেয়ার করলে ${bn(ri(cfg['share_coin']))} কয়েন। '
          '${bn(ri(cfg['coins_per_taka']))} কয়েন = ১ টাকা, বিকাশে তুলুন।',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
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
        if (ri(cfg['open']) == 0) ...[
          const SizedBox(height: 8),
          Text('রিওয়ার্ড সিস্টেম এখন বন্ধ আছে।', textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- ড্যাশবোর্ড
class _Dashboard extends StatefulWidget {
  const _Dashboard();

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await RewardApi.refreshMe();
      if (mounted) setState(() => _err = null);
    } on RewardError catch (e) {
      if (mounted) setState(() => _err = e.message);
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
        title: const Text('বিকাশে টাকা তুলুন'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${bn(payCoins)} কয়েন = ৳${bn(payTaka)} টাকা', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 12),
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
          IconButton(
            tooltip: 'ইতিহাস',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardHistoryScreen())),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'out') await RewardApi.logout();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'out', child: Text('লগআউট'))],
          ),
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

  Widget _bar(String label, int v, int max, Color color) {
    final p = max <= 0 ? 0.0 : (v / max).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('${bn(v)} / ${bn(max)}'),
        ]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: p, minHeight: 8, color: color)),
      ]),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> m) {
    final cfg = m['config'] is Map ? Map<String, dynamic>.from(m['config'] as Map) : RewardApi.cfg;
    final user = m['user'] is Map ? Map<String, dynamic>.from(m['user'] as Map) : <String, dynamic>{};
    final wd = m['withdrawal'] is Map ? Map<String, dynamic>.from(m['withdrawal'] as Map) : null;
    final coins = ri(m['coins']);
    final pend = ri(m['pending_coins']);
    final minCoins = ri(m['min_coins']);
    final open = ri(cfg['open']) != 0;
    final notice = '${cfg['notice'] ?? ''}'.trim();
    final shareCoin = ri(cfg['share_coin']);
    final cs = Theme.of(context).colorScheme;

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (!open)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(12)),
          child: const Text('রিওয়ার্ড সিস্টেম এখন সাময়িক বন্ধ আছে।'),
        ),
      if (notice.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.withAlpha(40), borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.campaign_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(notice)),
          ]),
        ),
      // ব্যালেন্স কার্ড
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [AppConfig.brand, Color.lerp(AppConfig.brand, Colors.white, 0.2)!]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('স্বাগতম, ${user['name'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Icon(Icons.monetization_on_rounded, color: Colors.amber.shade400, size: 34),
            const SizedBox(width: 8),
            Text(bn(coins), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1)),
            const SizedBox(width: 8),
            const Padding(padding: EdgeInsets.only(bottom: 5), child: Text('কয়েন', style: TextStyle(color: Colors.white, fontSize: 17))),
          ]),
          const SizedBox(height: 8),
          Text('≈ ৳${_taka(m['taka'])} টাকা', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          if (pend > 0) ...[
            const SizedBox(height: 6),
            Text('যাচাইয়ের অপেক্ষায় শেয়ার: ${bn(pend)} কয়েন', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      // আজকের অগ্রগতি
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('আজকের অগ্রগতি', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _bar('খবর পড়ে কয়েন', ri(m['today_read']), ri(cfg['read_daily_max']), cs.primary),
            _bar('ফেসবুক শেয়ার জমা', ri(m['shares_today']), ri(cfg['share_daily_max']), Colors.green.shade600),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      // নিয়ম
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('কীভাবে কয়েন পাবেন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _rule(Icons.menu_book_outlined, 'যেকোনো খবর খুলে ${bn(ri(cfg['read_seconds']))} সেকেন্ড পড়লে ${bn(ri(cfg['read_coin']))} কয়েন (দিনে সর্বোচ্চ ${bn(ri(cfg['read_daily_max']))})'),
            _rule(Icons.share_outlined, 'ফেসবুকে শেয়ার করে স্ক্রিনশট জমা দিলে ${bn(shareCoin)} কয়েন (অ্যাডমিন যাচাইয়ের পর)'),
            _rule(Icons.currency_exchange, '${bn(ri(cfg['coins_per_taka']))} কয়েন = ১ টাকা; ন্যূনতম ৳${bn(ri(cfg['min_withdraw']))} হলে বিকাশে তুলতে পারবেন'),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      // উত্তোলন
      if (wd != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _statusColor('${wd['status']}').withAlpha(25), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('চলমান উত্তোলন: ৳${_taka(wd['taka'])} • ${_statusLabel('${wd['status']}')}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('বিকাশ ${wd['bkash'] ?? ''} • ${_dt(wd['created'])}', style: const TextStyle(fontSize: 13)),
          ]),
        )
      else if (coins >= minCoins && coins > 0)
        FilledButton.icon(
          onPressed: (_busy || !open) ? null : () => _withdraw(m, cfg),
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)) : const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('বিকাশে টাকা তুলুন'),
        )
      else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(120), borderRadius: BorderRadius.circular(14)),
          child: Text('টাকা তুলতে আরও ${bn(max(0, minCoins - coins))} কয়েন লাগবে (ন্যূনতম ${bn(minCoins)} কয়েন)।'),
        ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _rule(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(t)),
        ]),
      );
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
          title: const Text('ইতিহাস'),
          bottom: const TabBar(tabs: [Tab(text: 'কয়েন'), Tab(text: 'শেয়ার'), Tab(text: 'উত্তোলন')]),
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
      title: Text('৳${_taka(r['taka'])} (${bn(ri(r['coins']))} কয়েন)'),
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
