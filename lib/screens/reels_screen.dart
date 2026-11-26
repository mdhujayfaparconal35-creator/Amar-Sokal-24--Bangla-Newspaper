import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../config.dart';
import '../dynamic_ui.dart';
import '../shell_state.dart';
import '../util.dart';

class ReelItem {
  final String id, title, thumb, url, permalink;
  const ReelItem(this.id, this.title, this.thumb, this.url, this.permalink);
  factory ReelItem.fromJson(Map<String, dynamic> j) => ReelItem('${j['id']}', '${j['title'] ?? ''}', '${j['thumb'] ?? ''}', '${j['url'] ?? ''}', '${j['permalink'] ?? ''}');
}

/// "রিলস" ট্যাব: ফেসবুক পেজের রিলস অ্যাপের নিজস্ব প্লেয়ারে চলে। প্রথম রিলস নিজে চলে,
/// ওপরে স্ক্রল (সোয়াইপ) করলে একটার পর একটা আসে। (লিংক T2 সার্ভার থেকে আসে — ফেসবুকের ওয়েবসাইট লগইন চায়, তাই সেটা নয়।)
class ReelsScreen extends StatefulWidget {
  final bool inShell;
  const ReelsScreen({super.key, this.inShell = false});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver, RouteAware {
  List<ReelItem> _items = [];
  bool _loading = true;
  String? _err;
  final PageController _pc = PageController();
  final Map<int, VideoPlayerController> _vc = {};
  int _cur = 0;
  bool _muted = false;
  bool _hint = true;
  bool _tabOn = true;
  bool _routeOn = true;
  bool _appOn = true;
  PageRoute<dynamic>? _route;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabOn = !widget.inShell || TabNav.current.value == 'story';
    TabNav.current.addListener(_onTab);
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _hint = false);
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
    appRouteObserver.unsubscribe(this);
    _hintTimer?.cancel();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await http.get(Uri.parse('${AppConfig.t2Base}/reels_api.php')).timeout(const Duration(seconds: 25));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final list = (j is Map && j['items'] is List) ? (j['items'] as List) : const [];
      final items = list.map((e) => ReelItem.fromJson(Map<String, dynamic>.from(e as Map))).where((e) => e.url.startsWith('http')).toList();
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _items = [];
          _loading = false;
          _err = (j is Map && j['msg'] != null) ? '${j['msg']}' : 'এখন কোনো রিলস পাওয়া যাচ্ছে না।';
        });
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
        _cur = 0;
      });
      _ensure(0);
      _ensure(1);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _err = 'ইন্টারনেট সংযোগ নেই বা সার্ভার সাড়া দিচ্ছে না।';
        });
      }
    }
  }

  void _ensure(int i) {
    if (i < 0 || i >= _items.length || _vc.containsKey(i)) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(_items[i].url));
    _vc[i] = c;
    c.initialize().then((_) {
      c.setLooping(true);
      c.setVolume(_muted ? 0 : 1);
      if (!mounted) return;
      setState(() {});
      if (i == _cur) _sync();
    }).catchError((_) {
      if (mounted) setState(() {});
    });
  }

  void _onPage(int i) {
    _vc[_cur]?.pause();
    _cur = i;
    for (final k in _vc.keys.toList()) {
      if ((k - i).abs() > 1) {
        _vc.remove(k)?.dispose();
      }
    }
    _ensure(i);
    _ensure(i + 1);
    _ensure(i - 1);
    _vc[i]?.seekTo(Duration.zero);
    setState(() => _hint = false);
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

  Widget _act(IconData i, String label, VoidCallback f) => GestureDetector(
        onTap: f,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: Icon(i, color: Colors.white, size: 24),
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
    return Stack(fit: StackFit.expand, children: [
      if (!ready && it.thumb.startsWith('http')) Image.network(it.thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      if (ready)
        GestureDetector(
          onTap: () => _togglePlay(c!),
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
              const IgnorePointer(child: Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 72))),
          ]),
        )
      else
        const Center(child: CircularProgressIndicator(color: Colors.white)),
      const Positioned(left: 0, right: 0, bottom: 0, height: 220, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]))))),
      Positioned(
        left: 16,
        right: 84,
        bottom: 28,
        child: IgnorePointer(
          child: Text(it.title.isEmpty ? 'আমার সকাল ২৪' : it.title, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 6)])),
        ),
      ),
      Positioned(
        right: 8,
        bottom: 40,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _act(_muted ? Icons.volume_off : Icons.volume_up, _muted ? 'শব্দ বন্ধ' : 'শব্দ চালু', _toggleMute),
          _act(Icons.share, 'শেয়ার', () => shareTo(context, 'fb', it.title.isEmpty ? 'আমার সকাল ২৪ রিলস' : it.title, it.permalink)),
          _act(Icons.open_in_new, 'ফেসবুকে', () => openExternal(it.permalink.isEmpty ? AppConfig.reelsUrl : it.permalink)),
        ]),
      ),
      if (ready) Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(c!, allowScrubbing: false, padding: EdgeInsets.zero, colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white30, backgroundColor: Colors.white12))),
    ]);
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.white));
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
            FilledButton(onPressed: _load, child: const Text('আবার চেষ্টা করুন')),
            TextButton(onPressed: () => openExternal(AppConfig.reelsUrl), child: const Text('ফেসবুকে দেখুন')),
          ]),
        ),
      );
    }
    return Stack(children: [
      PageView.builder(scrollDirection: Axis.vertical, controller: _pc, itemCount: _items.length, onPageChanged: _onPage, itemBuilder: (_, i) => _page(i)),
      Positioned(
        top: 10,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
              child: Text('রিলস ${bn(_cur + 1)} / ${bn(_items.length)}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
      if (_hint)
        Positioned(
          left: 24,
          right: 24,
          bottom: 110,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.black.withAlpha(190), borderRadius: BorderRadius.circular(22)),
              child: const Text('ওপরে স্ক্রল (সোয়াইপ) করলে পরের রিলস আসবে', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
    ]);
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
