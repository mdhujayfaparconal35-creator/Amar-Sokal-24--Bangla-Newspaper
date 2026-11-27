import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../config.dart';
import '../fake_stats.dart';
import '../fb/fb_media.dart';
import '../rewards/media_reward.dart';
import '../util.dart';
import '../widgets.dart';

/// ফেসবুক পেজের ভিডিও অ্যাপের নিজস্ব প্লেয়ারে: প্লে/পজ, ১০ সেকেন্ড আগে-পিছে (ডাবল-ট্যাপ), টেনে এগোনো, ফুলস্ক্রিন।
/// নিচে শেয়ার, ফেসবুকে দেখা ও আরও ভিডিও।
class FbVideoPlayerScreen extends StatefulWidget {
  final FbVideo video;
  final List<FbVideo> others;
  const FbVideoPlayerScreen({super.key, required this.video, this.others = const []});

  @override
  State<FbVideoPlayerScreen> createState() => _FbVideoPlayerScreenState();
}

class _FbVideoPlayerScreenState extends State<FbVideoPlayerScreen> {
  VideoPlayerController? _c;
  bool _failed = false;
  bool _controls = true;
  bool _fs = false;
  bool _muted = false;
  Timer? _hide;
  final MediaRewardTracker _rw = MediaRewardTracker('video');

  FbVideo get v => widget.video;

  @override
  void initState() {
    super.initState();
    _rw.reset(v.id);
    FakeStats.bumpMedia(v.id); // প্রতিবার দেখলে ভিউ ৭ করে বাড়ে
    _init();
  }

  Future<void> _init() async {
    setState(() => _failed = false);
    final c = VideoPlayerController.networkUrl(Uri.parse(v.url));
    _c = c;
    try {
      await c.initialize();
      if (!mounted) return;
      await c.setVolume(_muted ? 0 : 1);
      c.addListener(_tick);
      await c.play();
      setState(() {});
      _autoHide();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _tick() {
    final c = _c;
    if (c != null && c.value.isInitialized) _rw.onTick(c.value.position, c.value.duration, c.value.isPlaying);
    if (mounted) setState(() {});
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && (_c?.value.isPlaying ?? false)) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _autoHide();
  }

  void _playPause() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      _hide?.cancel();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
      _autoHide();
    }
  }

  void _skip(int sec) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    var t = c.value.position + Duration(seconds: sec);
    if (t < Duration.zero) t = Duration.zero;
    if (t > c.value.duration) t = c.value.duration;
    c.seekTo(t);
  }

  void _enterFs() {
    setState(() => _fs = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (v.aspect >= 1.2) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  void _exitFs() {
    setState(() => _fs = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c?.removeListener(_tick);
    _c?.dispose();
    _rw.dispose();
    if (_fs) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return bn('$m:$s');
  }

  Widget _player() {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final val = c?.value;
    return ColoredBox(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        if (!ready && v.thumb.startsWith('http')) Image.network(v.thumb, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        if (ready) Center(child: AspectRatio(aspectRatio: c!.value.aspectRatio, child: VideoPlayer(c!))),
        // ট্যাপ = নিয়ন্ত্রণ দেখান/লুকান; ডাবল-ট্যাপ বাঁ/ডান = ১০ সেকেন্ড পেছনে/সামনে
        Positioned.fill(
          child: Row(children: [
            Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _toggleControls, onDoubleTap: () => _skip(-10))),
            Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _toggleControls, onDoubleTap: () => _skip(10))),
          ]),
        ),
        Positioned(top: 10, left: 10, child: SafeArea(child: MediaRewardBadge(tracker: _rw))),
        if (_failed)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 44),
              const SizedBox(height: 8),
              const Text('ভিডিওটি চালানো যায়নি', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: _init, child: const Text('আবার চেষ্টা')),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                  onPressed: () => openLink(v.permalink),
                  child: const Text('ফেসবুকে দেখুন'),
                ),
              ]),
            ]),
          )
        else if (!ready || (val?.isBuffering ?? false))
          const Center(child: SizedBox(width: 38, height: 38, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
        if (ready && !_failed)
          IgnorePointer(
            ignoring: !_controls,
            child: AnimatedOpacity(
              opacity: _controls ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Stack(fit: StackFit.expand, children: [
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black45, Colors.transparent, Colors.transparent, Colors.black87], stops: [0, 0.3, 0.6, 1])),
                ),
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(iconSize: 36, color: Colors.white, onPressed: () => _skip(-10), icon: const Icon(Icons.replay_10_rounded)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: _playPause,
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(color: Colors.black.withAlpha(130), shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 1.6)),
                        child: Icon(c!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 42),
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(iconSize: 36, color: Colors.white, onPressed: () => _skip(10), icon: const Icon(Icons.forward_10_rounded)),
                  ]),
                ),
                Positioned(
                  left: 12,
                  right: 6,
                  bottom: 4,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Text(_fmt(c!.value.position), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
                          child: Slider(
                            value: c!.value.position.inMilliseconds.clamp(0, c!.value.duration.inMilliseconds).toDouble(),
                            max: c!.value.duration.inMilliseconds <= 0 ? 1 : c!.value.duration.inMilliseconds.toDouble(),
                            activeColor: const Color(0xFFFFB300),
                            inactiveColor: Colors.white30,
                            onChangeStart: (_) => _hide?.cancel(),
                            onChanged: (x) => c!.seekTo(Duration(milliseconds: x.round())),
                            onChangeEnd: (_) => _autoHide(),
                          ),
                        ),
                      ),
                      Text(_fmt(c!.value.duration), style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        color: Colors.white,
                        onPressed: () {
                          setState(() => _muted = !_muted);
                          c!.setVolume(_muted ? 0 : 1);
                        },
                        icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        color: Colors.white,
                        onPressed: _fs ? _exitFs : _enterFs,
                        icon: Icon(_fs ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fs) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitFs();
        },
        child: Scaffold(backgroundColor: Colors.black, body: SizedBox.expand(child: _player())),
      );
    }
    final more = widget.others.where((e) => e.id != v.id).toList();
    final t = Theme.of(context);
    final ago = timeAgo(v.created);
    return Scaffold(
      appBar: AppBar(title: const Text('ভিডিও')),
      body: ListView(padding: EdgeInsets.zero, children: [
        AspectRatio(aspectRatio: v.square ? 1.0 : 16 / 9, child: _player()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(v.title.isEmpty ? AppConfig.siteName : v.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.4)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text('${AppConfig.siteName}${ago.isEmpty ? '' : '  •  $ago'}  •  ${FakeStats.fmt(FakeStats.mediaViews(v.id))} বার দেখা', style: TextStyle(fontSize: 13.5, color: t.colorScheme.outline)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            Expanded(child: ShareRow(title: v.title.isEmpty ? AppConfig.siteName : v.title, link: v.permalink)),
            OutlinedButton.icon(
              onPressed: () => openLink(v.permalink),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('ফেসবুকে'),
            ),
          ]),
        ),
        if (more.isNotEmpty) const SectionTitle('আরও ভিডিও'),
        for (final e in more)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => FbVideoPlayerScreen(video: e, others: widget.others))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 150,
                    height: e.square ? 150 : 84,
                    child: Stack(fit: StackFit.expand, children: [
                      Container(color: Colors.black),
                      if (e.thumb.startsWith('http')) Image.network(e.thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 32)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title.isEmpty ? AppConfig.siteName : e.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.35)),
                    const SizedBox(height: 4),
                    Text('${FakeStats.fmt(FakeStats.mediaViews(e.id))} বার দেখা', style: TextStyle(fontSize: 12, color: t.colorScheme.outline)),
                  ]),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 20),
      ]),
    );
  }
}
