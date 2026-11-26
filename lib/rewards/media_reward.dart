import 'dart:async';
import 'package:flutter/material.dart';
import '../util.dart';
import 'reward_api.dart';
import 'reward_screens.dart';

enum MediaState { off, login, watching, claiming, done, already, limit, error }

/// বড়ো ভিডিও ("video") বা রিলস ("reel") সত্যিই দেখা হলো কিনা গোনে, শেষে সার্ভার থেকে কয়েন নেয়।
/// আসল যাচাই সার্ভারে; অ্যাপ শুধু আসলে-চলা সময় গোনে (সিক/স্কিপ করলে সময় বাড়ে না)।
///
/// v1.15.1: আগে "শুরু" বা "দাবি" একবার ফেল করলেই কয়েন চিরতরে হারাত (কোনো পুনরায় চেষ্টা ছিল না, এরর-ও দেখাত না)।
/// এখন: শুরুর অনুরোধ সফল না হওয়া পর্যন্ত বারবার চেষ্টা, দাবিতে নেটওয়ার্ক/"early" সমস্যায় নিজে নিজে আবার চেষ্টা,
/// আর শেষ পর্যন্ত না হলে সার্ভারের আসল বার্তা দেখিয়ে ট্যাপ করে আবার চেষ্টার সুযোগ।
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
  String errorMsg = '';
  Duration _last = Duration.zero;
  bool _started = false, _startOk = false, _claimed = false, _disposed = false;
  int _gen = 0; // reset হলে পুরনো অনুরোধের ফল বাতিল করতে

  int get coin => ri(RewardApi.cfg[kind == 'video' ? 'video_coin' : 'reel_coin']);
  double get progress => duration <= 0 ? 0 : (watched / (duration * needFraction)).clamp(0.0, 1.0).toDouble();

  bool get _open => ri(RewardApi.cfg['open']) != 0 && coin > 0;

  void _loginChanged() => reset(_id);

  void reset(String id) {
    _gen++;
    _id = id;
    watched = 0;
    duration = 0;
    earned = 0;
    errorMsg = '';
    _last = Duration.zero;
    _started = false;
    _startOk = false;
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
      // (ফোন একটু আটকে গেলেও যেন সময় হারিয়ে না যায়, তাই সীমা ৩ সেকেন্ড)
      if (d > 0 && d < 3000) watched += d / 1000;
      if (!_started) {
        _started = true;
        _startLoop(dur.inSeconds);
      }
    }
    _last = pos;
    if (watched >= duration * needFraction && state == MediaState.watching && _startOk) {
      _claim();
    } else {
      _notify();
    }
  }

  /// সার্ভারকে "দেখা শুরু" জানানো; ফেল করলে কয়েকবার আবার চেষ্টা (এটা না হলে সার্ভার কয়েন দেয় না)
  Future<void> _startLoop(int dur) async {
    final g = _gen;
    final id = _id;
    for (var i = 0; i < 6; i++) {
      try {
        await RewardApi.mediaStart(kind, id, dur);
        if (g == _gen) _startOk = true;
        return;
      } on RewardError catch (e) {
        if (g != _gen || _disposed) return;
        if (e.status == 404 || e.status == 403) {
          // সার্ভারে ফিচার নেই/বন্ধ: পিল লুকিয়ে ফেলি
          state = MediaState.off;
          _notify();
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 4));
      if (g != _gen || _disposed) return;
    }
    if (g == _gen && !_disposed) {
      errorMsg = 'সার্ভারের সাথে যোগাযোগ হচ্ছে না।';
      state = MediaState.error;
      _notify();
    }
  }

  Future<void> _claim() async {
    _claimed = true;
    state = MediaState.claiming;
    errorMsg = '';
    _notify();
    final g = _gen;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final j = await RewardApi.mediaClaim(kind, _id, watched.round(), duration.round());
        if (g != _gen || _disposed) return;
        switch ('${j['state']}') {
          case 'ok':
            earned = ri(j['earned']);
            if (earned <= 0) earned = coin;
            state = MediaState.done;
            _notify();
            RewardApi.refreshMe().then((_) {}).catchError((_) {});
            return;
          case 'claimed':
            state = MediaState.already;
            _notify();
            return;
          case 'limit':
            state = MediaState.limit;
            _notify();
            return;
          case 'early':
            // সার্ভারের হিসাবে একটু বাকি — একটু থেমে আবার
            if (attempt < 3) {
              final w = (ri(j['wait']) + 1).clamp(2, 20).toInt();
              await Future.delayed(Duration(seconds: w));
              if (g != _gen || _disposed) return;
              continue;
            }
            errorMsg = 'সার্ভারের হিসাবে এখনো সময় বাকি।';
            break;
          default:
            errorMsg = '${j['message'] ?? 'অপ্রত্যাশিত উত্তর (${j['state']})'}';
        }
        state = MediaState.error;
        _notify();
        return;
      } on RewardError catch (e) {
        if (g != _gen || _disposed) return;
        // নেটওয়ার্ক/সার্ভার ত্রুটি (0, ৫xx) ও ৪০০/৪২৯ ("early" ধরনের) হলে একটু পরে আবার চেষ্টা
        final retryable = e.status == 0 || e.status >= 500 || e.status == 400 || e.status == 425 || e.status == 429;
        if (retryable && attempt < 3) {
          await Future.delayed(Duration(seconds: 3 + attempt * 3));
          if (g != _gen || _disposed) return;
          continue;
        }
        errorMsg = e.message;
        state = MediaState.error;
        _notify();
        return;
      } catch (_) {
        if (g != _gen || _disposed) return;
        errorMsg = 'অজানা সমস্যা হয়েছে।';
        state = MediaState.error;
        _notify();
        return;
      }
    }
  }

  /// এরর পিলে ট্যাপ করলে আবার চেষ্টা
  void retry() {
    if (state != MediaState.error) return;
    if (_startOk) {
      _claim();
    } else {
      reset(_id); // শুরুই হয়নি: নতুন করে গোনা
    }
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
            w = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: _pill(
                Colors.red.shade700,
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      _txt('কয়েন নেওয়া যায়নি • আবার চেষ্টা'),
                      if (t.errorMsg.isNotEmpty)
                        Text(t.errorMsg, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                    ]),
                  ),
                ]),
                onTap: t.retry,
              ),
            );
            break;
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(t.state), child: w));
      },
    );
  }
}

Widget rewardCoinSmall() => const Icon(Icons.monetization_on_rounded, color: Colors.amberAccent, size: 20);
