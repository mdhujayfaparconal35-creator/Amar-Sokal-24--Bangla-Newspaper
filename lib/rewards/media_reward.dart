import 'dart:async';
import 'package:flutter/material.dart';
import '../util.dart';
import 'reward_api.dart';
import 'reward_screens.dart';

enum MediaState { off, login, watching, claiming, done, already, limit, error }

/// বড়ো ভিডিও ("video") বা রিলস ("reel") সত্যিই দেখা হলো কিনা গোনে, শেষে সার্ভার থেকে কয়েন নেয়।
/// আসল যাচাই সার্ভারে; অ্যাপ শুধু আসলে-চলা সময় গোনে (সিক/স্কিপ করলে সময় বাড়ে না)।
class MediaRewardTracker extends ChangeNotifier {
  final String kind;
  final double needFraction;
  MediaRewardTracker(this.kind, {this.needFraction = 0.9}) {
    RewardApi.loggedIn.addListener(_loginChanged);
  }

  String _id = '';
  MediaState state = MediaState.off;
  int earned = 0;
  double watched = 0;
  double duration = 0;
  Duration _last = Duration.zero;
  bool _started = false, _claimed = false, _disposed = false;

  int get coin => ri(RewardApi.cfg[kind == 'video' ? 'video_coin' : 'reel_coin']);
  double get progress => duration <= 0 ? 0 : (watched / (duration * needFraction)).clamp(0.0, 1.0).toDouble();

  bool get _open => ri(RewardApi.cfg['open']) != 0 && coin > 0;

  void _loginChanged() => reset(_id);

  void reset(String id) {
    _id = id;
    watched = 0;
    duration = 0;
    earned = 0;
    _last = Duration.zero;
    _started = false;
    _claimed = false;
    state = !_open ? MediaState.off : (RewardApi.loggedIn.value ? MediaState.watching : MediaState.login);
    _notify();
  }

  /// প্লেয়ারের প্রতিটি আপডেটে ডাকুন
  void onTick(Duration pos, Duration dur, bool playing) {
    if (_claimed || state == MediaState.off || state == MediaState.login || dur.inSeconds < 3) return;
    duration = dur.inMilliseconds / 1000;
    if (playing) {
      final d = (pos - _last).inMilliseconds;
      // স্বাভাবিক চলা: ছোট ধাপ। বড়ো লাফ (সিক) বা পেছনে যাওয়া (লুপ) গোনা হয় না, লুপে নতুন পাক শুরু হয়
      if (d > 0 && d < 1500) watched += d / 1000;
      if (!_started) {
        _started = true;
        RewardApi.mediaStart(kind, _id, dur.inSeconds).then((_) {}).catchError((e) {
          if (e is RewardError && (e.status == 404 || e.status == 403)) {
            state = MediaState.off;
            _notify();
          }
        });
      }
    }
    _last = pos;
    if (watched >= duration * needFraction && state == MediaState.watching) {
      _claim();
    } else {
      _notify();
    }
  }

  Future<void> _claim() async {
    _claimed = true;
    state = MediaState.claiming;
    _notify();
    try {
      final j = await RewardApi.mediaClaim(kind, _id, watched.round(), duration.round());
      switch ('${j['state']}') {
        case 'ok':
          earned = ri(j['earned']);
          state = MediaState.done;
          RewardApi.refreshMe().then((_) {}).catchError((_) {});
          break;
        case 'claimed':
          state = MediaState.already;
          break;
        case 'limit':
          state = MediaState.limit;
          break;
        default:
          state = MediaState.error;
      }
    } on RewardError catch (e) {
      state = (e.status == 404 || e.status == 403) ? MediaState.off : MediaState.error;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    RewardApi.loggedIn.removeListener(_loginChanged);
    super.dispose();
  }
}

/// ভিডিও/রিলসের ওপরে ছোট কয়েন-পিল: প্রগ্রেস রিং, শেষে "+৭ কয়েন"
class MediaRewardBadge extends StatelessWidget {
  final MediaRewardTracker tracker;
  const MediaRewardBadge({super.key, required this.tracker});

  Widget _pill(Color bg, Widget child, {VoidCallback? onTap}) => Material(
        color: bg,
        elevation: 4,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.fromLTRB(10, 6, 14, 6), child: child),
        ),
      );

  Widget _txt(String s) => Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final t = tracker;
        final full = t.kind == 'video' ? 'পুরো ভিডিও দেখুন' : 'রিলস দেখুন';
        Widget w;
        switch (t.state) {
          case MediaState.off:
            w = const SizedBox.shrink();
            break;
          case MediaState.login:
            w = _pill(
              Colors.amber.shade800,
              Row(mainAxisSize: MainAxisSize.min, children: [
                rewardCoinSmall(),
                const SizedBox(width: 6),
                _txt('লগইন করে ${bn(t.coin)} কয়েন জিতুন'),
              ]),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardScreen())),
            );
            break;
          case MediaState.watching:
          case MediaState.claiming:
            w = _pill(
              Colors.black.withAlpha(160),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: t.state == MediaState.claiming ? null : t.progress,
                      strokeWidth: 3,
                      color: Colors.amber,
                      backgroundColor: Colors.white24,
                    ),
                    const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 13),
                  ]),
                ),
                const SizedBox(width: 8),
                _txt(t.state == MediaState.claiming ? 'কয়েন যোগ হচ্ছে…' : '$full • +${bn(t.coin)} কয়েন'),
              ]),
            );
            break;
          case MediaState.done:
            w = _pill(
              Colors.green.shade700,
              Row(mainAxisSize: MainAxisSize.min, children: [rewardCoinSmall(), const SizedBox(width: 6), _txt('+${bn(t.earned)} কয়েন পেয়েছেন')]),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardScreen())),
            );
            break;
          case MediaState.already:
            w = _pill(Colors.grey.shade800, Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 6), _txt('কয়েন আগেই নেওয়া হয়েছে')]));
            break;
          case MediaState.limit:
            w = _pill(Colors.orange.shade800, _txt('আজকের কয়েন সীমা শেষ'));
            break;
          case MediaState.error:
            w = _pill(Colors.red.shade700, _txt('কয়েন নেওয়া যায়নি'));
            break;
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(t.state), child: w));
      },
    );
  }
}

Widget rewardCoinSmall() => const Icon(Icons.monetization_on_rounded, color: Colors.amberAccent, size: 20);
