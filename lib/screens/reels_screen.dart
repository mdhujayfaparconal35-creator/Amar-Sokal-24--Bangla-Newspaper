import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config.dart';
import '../dynamic_ui.dart';
import '../fake_stats.dart';
import '../fb/fb_media.dart';
import '../shell_state.dart';
import '../rewards/media_reward.dart';
import '../util.dart';

/// "রিলস" ট্যাব: ফেসবুক পেজের লম্বা ভিডিও (সর্বোচ্চ ৫০টি) অ্যাপের নিজস্ব প্লেয়ারে চলে।
/// প্রথমটা নিজে চলে; ওপরে স্ক্রল (সোয়াইপ) করলেই পরেরটা আসে — কোনো গণনা/সংখ্যা দেখায় না, শেষ পর্যন্ত এভাবেই চলে।
class ReelsScreen extends StatefulWidget {
  final bool inShell;
  const ReelsScreen({super.key, this.inShell = false});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver, RouteAware, TickerProviderStateMixin {
  List<FbVideo> _items = [];
  bool _loading = true;
  String? _err;
  final PageController _pc = PageController();
  final Map<int, VideoPlayerController> _vc = {};
  final Set<String> _failed = {};
  final Set<String> _viewed = {}; // এই স্ক্রিনে যে রিলসের ভিউ একবার গোনা হয়েছে
  int _cur = 0;
  final MediaRewardTracker _rw = MediaRewardTracker('reel');
  Timer? _rwTimer;
  VoidCallback? _unRe;
  bool _muted = false;
  bool _tabOn = true;
  bool _routeOn = true;
  bool _appOn = true;
  PageRoute<dynamic>? _route;

  // ডাবল-ট্যাপে হৃদয়
  Offset? _heartAt;
  Offset _tapPos = Offset.zero;
  late final AnimationController _heartC = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabOn = !widget.inShell || TabNav.current.value == 'story';
    TabNav.current.addListener(_onTab);
    // রিলসে থেকে রিলস মেনুতে আবার ট্যাপ করলে প্রথম রিলসে ফিরে যায়
    _unRe = TabNav.onReselect('story', () {
      if (_pc.hasClients && _cur != 0) _pc.animateToPage(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
    // রিলসের আসলে-চলা সময় গোনা (প্রতি আধা সেকেন্ডে)
    _rwTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final c = _vc[_cur];
      if (c == null || !c.value.isInitialized || _items.isEmpty) return;
      _rw.onTick(c.value.position, c.value.duration, c.value.isPlaying);
    });
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (r is PageRoute && r != _route) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, r);
      _route = r;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TabNav.current.removeListener(_onTab);
    _unRe?.call();
    appRouteObserver.unsubscribe(this);
    _rwTimer?.cancel();
    _rw.dispose();
    _heartC.dispose();
    for (final c in _vc.values) {
      c.dispose();
    }
    _vc.clear();
    _pc.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _routeOn = false;
    _sync();
  }

  @override
  void didPopNext() {
    _routeOn = true;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appOn = state == AppLifecycleState.resumed;
    _sync();
  }

  void _onTab() {
    _tabOn = !widget.inShell || TabNav.current.value == 'story';
    _sync();
  }

  /// ট্যাব/পেজ/অ্যাপ সামনে থাকলে বর্তমান রিলস চলে, নইলে থামে
  void _sync() {
    final on = _tabOn && _routeOn && _appOn;
    final c = _vc[_cur];
    if (c == null || !c.value.isInitialized) return;
    if (on) {
      c.play();
    } else {
      c.pause();
    }
  }

  void _disposeAll() {
    for (final c in _vc.values) {
      c.dispose();
    }
    _vc.clear();
    _failed.clear();
  }

  Future<void> _load() async {
    // আগেরবারের তালিকা থাকলে সাথে সাথে দেখাই, পেছনে নতুনটা আনি
    final cached = await FbMedia.cached('reels');
    if (cached != null && mounted) {
      setState(() {
        _items = cached.items;
        _loading = false;
        _err = null;
      });
      _ensure(0);
      _ensure(1);
      _rw.reset(cached.items.first.id);
      _countView(cached.items.first.id);
    }
    final f = await FbMedia.reels();
    if (!mounted) return;
    if (f.items.isEmpty) {
      if (_items.isEmpty) {
        setState(() {
          _loading = false;
          _err = f.error ?? 'এখন কোনো রিলস পাওয়া যাচ্ছে না।';
        });
      }
      return;
    }
    // ব্যবহারকারী এখনো প্রথম রিলসেই থাকলে নতুন তালিকা বসাই (নতুন ভিডিও-লিংক); স্ক্রল করে থাকলে বিরক্ত করি না
    if (_items.isEmpty || _cur == 0) {
      _disposeAll();
      setState(() {
        _items = f.items;
        _loading = false;
        _err = null;
        _cur = 0;
      });
      _ensure(0);
      _ensure(1);
      _rw.reset(f.items.first.id);
      _countView(f.items.first.id);
    }
  }

  void _countView(String id) {
    if (_viewed.add(id)) FakeStats.bumpMedia(id); // প্রতিটি রিলস দেখলে ভিউ ৭ করে বাড়ে
  }

  void _ensure(int i) {
    if (i < 0 || i >= _items.length || _vc.containsKey(i)) return;
    final id = _items[i].id;
    final c = VideoPlayerController.networkUrl(Uri.parse(_items[i].url));
    _vc[i] = c;
    c.initialize().then((_) {
      c.setLooping(true);
      c.setVolume(_muted ? 0 : 1);
      if (!mounted) return;
      setState(() {});
      if (i == _cur) _sync();
    }).catchError((_) {
      _failed.add(id);
      if (mounted) setState(() {});
    });
  }

  void _onPage(int i) {
    _vc[_cur]?.pause();
    _cur = i;
    if (i < _items.length) {
      _rw.reset(_items[i].id);
      _countView(_items[i].id);
    }
    for (final k in _vc.keys.toList()) {
      if ((k - i).abs() > 1) {
        _vc.remove(k)?.dispose();
      }
    }
    _ensure(i);
    _ensure(i + 1);
    _ensure(i - 1);
    _vc[i]?.seekTo(Duration.zero);
    setState(() {});
    _sync();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    for (final c in _vc.values) {
      c.setVolume(_muted ? 0 : 1);
    }
  }

  void _togglePlay(VideoPlayerController c) {
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  void _like(FbVideo it, {bool fromDoubleTap = false}) {
    setState(() {
      if (fromDoubleTap) {
        FakeStats.setLiked(it.id, true);
      } else {
        FakeStats.toggleLike(it.id);
      }
      if (fromDoubleTap) {
        _heartAt = _tapPos;
        _heartC.forward(from: 0);
      }
    });
  }

  void _retry(int i) {
    _vc.remove(i)?.dispose();
    _failed.remove(_items[i].id);
    setState(() {});
    _ensure(i);
  }

  Widget _act(IconData i, String label, VoidCallback f, {Color color = Colors.white}) => GestureDetector(
        onTap: f,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Colors.black.withAlpha(95), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
              child: Icon(i, color: color, size: 25),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 4)])),
          ]),
        ),
      );

  Widget _page(int i) {
    final it = _items[i];
    final c = _vc[i];
    final ready = c?.value.isInitialized ?? false;
    final bad = _failed.contains(it.id);
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),
      if (!ready && it.thumb.startsWith('http')) Image.network(it.thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      if (ready)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _togglePlay(c!),
          onDoubleTapDown: (d) => _tapPos = d.localPosition,
          onDoubleTap: () => _like(it, fromDoubleTap: true),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: c!.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
            ),
          ),
        ),
      if (ready)
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c!,
          builder: (_, v, __) => Stack(fit: StackFit.expand, children: [
            if (v.isBuffering) const Center(child: CircularProgressIndicator(color: Colors.white)),
            if (!v.isPlaying && !v.isBuffering && i == _cur)
              const IgnorePointer(child: Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 74))),
          ]),
        )
      else if (bad)
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 46),
            const SizedBox(height: 8),
            const Text('রিলসটি চালানো যায়নি', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton(onPressed: () => _retry(i), child: const Text('আবার চেষ্টা')),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                onPressed: () => openLink(it.permalink),
                child: const Text('ফেসবুকে দেখুন'),
              ),
            ]),
          ]),
        )
      else
        const Center(child: CircularProgressIndicator(color: Colors.white)),
      const Positioned(top: 0, left: 0, right: 0, height: 110, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent]))))),
      const Positioned(left: 0, right: 0, bottom: 0, height: 260, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]))))),
      Positioned(
        left: 14,
        right: 84,
        bottom: 26,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover)),
            ),
            const SizedBox(width: 10),
            const Flexible(child: Text(AppConfig.siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6)]))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => openLink(AppConfig.reelsUrl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(border: Border.all(color: Colors.white70), borderRadius: BorderRadius.circular(8)),
                child: const Text('ফলো', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          if (it.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            IgnorePointer(child: Text(it.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 6)]))),
          ],
        ]),
      ),
      Positioned(
        right: 8,
        bottom: 34,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _act(Icons.remove_red_eye_outlined, FakeStats.fmt(FakeStats.mediaViews(it.id)), () {}),
          _act(FakeStats.isLiked(it.id) ? Icons.favorite : Icons.favorite_border, FakeStats.fmt(FakeStats.mediaLikeCount(it.id)), () => _like(it), color: FakeStats.isLiked(it.id) ? const Color(0xFFFF4D6D) : Colors.white),
          _act(Icons.share, 'শেয়ার', () => shareTo(context, 'fb', it.title.isEmpty ? 'আমার সকাল ২৪ রিলস' : it.title, it.permalink)),
          _act(_muted ? Icons.volume_off : Icons.volume_up, _muted ? 'শব্দ বন্ধ' : 'শব্দ', _toggleMute),
          _act(Icons.open_in_new, 'ফেসবুকে', () => openLink(it.permalink.isEmpty ? AppConfig.reelsUrl : it.permalink)),
        ]),
      ),
      if (i == _cur) Positioned(top: 12, left: 12, child: MediaRewardBadge(tracker: _rw)),
      if (i == _cur && _heartAt != null)
        Positioned(
          left: _heartAt!.dx - 50,
          top: _heartAt!.dy - 50,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _heartC,
              builder: (_, __) {
                final t = _heartC.value;
                final scale = t < 0.35 ? 0.4 + (t / 0.35) * 0.8 : 1.2 - (t - 0.35) * 0.3;
                final op = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
                return Opacity(opacity: op, child: Transform.scale(scale: scale, child: const Icon(Icons.favorite, color: Color(0xFFFF4D6D), size: 100, shadows: [Shadow(blurRadius: 18, color: Colors.black45)])));
              },
            ),
          ),
        ),
      if (ready) Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(c!, allowScrubbing: false, padding: EdgeInsets.zero, colors: const VideoProgressColors(playedColor: Color(0xFFFFB300), bufferedColor: Colors.white30, backgroundColor: Colors.white12))),
    ]);
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)));
    }
    if (_err != null || _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.video_library_outlined, size: 54, color: Colors.white54),
            const SizedBox(height: 12),
            const Text('রিলস লোড করা যায়নি', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_err ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _err = null;
                });
                _load();
              },
              child: const Text('আবার চেষ্টা করুন'),
            ),
            TextButton(onPressed: () => openLink(AppConfig.reelsUrl), child: const Text('ফেসবুকে দেখুন')),
          ]),
        ),
      );
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pc,
      itemCount: _items.length,
      onPageChanged: _onPage,
      itemBuilder: (_, i) => _page(i),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
      appBar: appHeader(context, back: !widget.inShell),
      body: _body(),
    );
  }
}
