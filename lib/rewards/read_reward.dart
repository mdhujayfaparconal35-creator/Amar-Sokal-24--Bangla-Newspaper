import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../util.dart';
import 'reward_api.dart';
import 'reward_screens.dart';

enum _S { off, login, loading, counting, claiming, done, already, limit, error }

/// খবরের পেজের কোণায় ভাসমান কয়েন-চিপ: পড়ার সময় গোনে, শেষ হলে সার্ভার থেকে কয়েন নেয়।
/// সময়ের আসল যাচাই সার্ভারে হয়; অ্যাপ বন্ধ/ব্যাকগ্রাউন্ডে থাকলে গোনা থেমে থাকে।
class ReadRewardChip extends StatefulWidget {
  final int postId;
  const ReadRewardChip({super.key, required this.postId});

  @override
  State<ReadRewardChip> createState() => _ReadRewardChipState();
}

class _ReadRewardChipState extends State<ReadRewardChip> with WidgetsBindingObserver {
  _S _s = _S.off;
  int _left = 0;
  int _total = 30;
  int _earned = 0;
  int _tries = 0;
  bool _fg = true;
  String _msg = '';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RewardApi.loggedIn.addListener(_begin);
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RewardApi.loggedIn.removeListener(_begin);
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _fg = state == AppLifecycleState.resumed;
  }

  Future<void> _begin() async {
    _t?.cancel();
    if (!mounted) return;
    if (ri(RewardApi.cfg['open']) == 0) {
      setState(() => _s = _S.off);
      return;
    }
    if (!RewardApi.loggedIn.value) {
      setState(() => _s = _S.login);
      return;
    }
    setState(() => _s = _S.loading);
    try {
      final j = await RewardApi.readStart(widget.postId);
      if (!mounted) return;
      if ('${j['state']}' == 'claimed') {
        setState(() => _s = _S.already);
        return;
      }
      _total = max(5, ri(j['seconds']));
      _left = _total;
      _tries = 0;
      _startTicking();
    } on RewardError catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = e.message;
        _s = (e.status == 403 || e.status == 404) ? _S.off : _S.error;
      });
    }
  }

  void _startTicking() {
    _t?.cancel();
    setState(() => _s = _S.counting);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (!_fg) return;
      _left--;
      if (_left <= 0) {
        t.cancel();
        _claim();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _claim() async {
    if (!mounted) return;
    setState(() => _s = _S.claiming);
    try {
      final j = await RewardApi.readClaim(widget.postId);
      if (!mounted) return;
      switch ('${j['state']}') {
        case 'ok':
          _earned = ri(j['earned']);
          setState(() => _s = _S.done);
          RewardApi.refreshMe().then((_) {}).catchError((_) {});
          break;
        case 'claimed':
          setState(() => _s = _S.already);
          break;
        case 'limit':
          setState(() => _s = _S.limit);
          break;
        case 'early':
          // সার্ভারের হিসাবে একটু বাকি (যেমন আগের নিউজের কয়েন এইমাত্র নেওয়া হয়েছে) — আবার গুনে চেষ্টা
          if (_tries++ < 3) {
            _left = max(2, ri(j['wait']) + 1);
            _startTicking();
          } else {
            setState(() {
              _msg = 'কয়েন নেওয়া যায়নি, পরে আবার চেষ্টা করুন।';
              _s = _S.error;
            });
          }
          break;
        default:
          setState(() => _s = _S.error);
      }
    } on RewardError catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = e.message;
        _s = _S.error;
      });
    }
  }

  Widget _pill(Color bg, Widget child, {VoidCallback? onTap}) => Material(
        color: bg,
        elevation: 4,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: child),
        ),
      );

  Widget _txt(String s) => Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5));

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final Widget w;
    switch (_s) {
      case _S.off:
      case _S.loading:
        w = const SizedBox.shrink();
        break;
      case _S.login:
        w = _pill(
          Colors.amber.shade800,
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            _txt('লগইন করে কয়েন জিতুন'),
          ]),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardScreen())),
        );
        break;
      case _S.counting:
      case _S.claiming:
        w = _pill(
          primary,
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                value: _s == _S.claiming ? null : (1 - _left / _total).clamp(0.0, 1.0).toDouble(),
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(width: 8),
            _txt(_s == _S.claiming ? 'কয়েন যোগ হচ্ছে…' : 'পড়ুন • ${bn(_left)} সেকেন্ড'),
          ]),
        );
        break;
      case _S.done:
        w = _pill(
          Colors.green.shade700,
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.monetization_on_rounded, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 6),
            _txt('+${bn(_earned)} কয়েন পেয়েছেন'),
          ]),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardScreen())),
        );
        break;
      case _S.already:
        w = _pill(Colors.grey.shade700, Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 6), _txt('এই খবরের কয়েন নেওয়া হয়েছে')]));
        break;
      case _S.limit:
        w = _pill(Colors.orange.shade800, _txt('আজকের পড়ার কয়েন সীমা শেষ'));
        break;
      case _S.error:
        w = _pill(
          Colors.red.shade700,
          Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.refresh, color: Colors.white, size: 18), const SizedBox(width: 6), Flexible(child: _txt(_msg.isEmpty ? 'আবার চেষ্টা করুন' : _msg))]),
          onTap: _begin,
        );
        break;
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: w);
  }
}
