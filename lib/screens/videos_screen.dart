import 'package:flutter/material.dart';
import '../config.dart';
import '../dynamic_ui.dart';
import '../fb/fb_media.dart';
import '../util.dart';
import 'fb_video_player_screen.dart';

/// "ভিডিও" পেজ: ফেসবুক পেজের ১৬:৯ (আড়াআড়ি) ও ১:১ (বর্গাকার) ভিডিও। লম্বা ভিডিও এখানে নয় — সেগুলো "রিলস" ট্যাবে।
/// আগেরবারের তালিকা সাথে সাথে দেখায়, পেছনে নতুনটা এনে বদলে দেয়।
class VideosScreen extends StatefulWidget {
  final bool inShell;
  const VideosScreen({super.key, this.inShell = false});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<FbVideo> _items = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = await FbMedia.cached('videos');
    if (c != null && mounted) {
      setState(() {
        _items = c.items;
        _loading = false;
      });
    }
    await _refresh(silent: c != null);
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = _items.isEmpty);
    final f = await FbMedia.videos();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (f.items.isNotEmpty) {
        _items = f.items;
        _err = null;
      } else if (_items.isEmpty) {
        _err = f.error ?? 'এখন কোনো ভিডিও পাওয়া যাচ্ছে না।';
      }
    });
  }

  void _open(FbVideo v) {
    Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => FbVideoPlayerScreen(video: v, others: _items),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  Widget _body() {
    if (_loading && _items.isEmpty) return const _VideoSkeleton();
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          const SizedBox(height: 90),
          Icon(Icons.smart_display_outlined, size: 62, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 14),
          const Center(child: Text('ভিডিও লোড করা যায়নি', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(_err ?? '', textAlign: TextAlign.center, style: TextStyle(height: 1.45, color: Theme.of(context).colorScheme.outline)),
          ),
          const SizedBox(height: 18),
          Center(child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('আবার চেষ্টা করুন'))),
          Center(child: TextButton(onPressed: () => openLink(AppConfig.reelsUrl.replaceFirst('/reels/', '/videos/')), child: const Text('ফেসবুকে দেখুন'))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        itemCount: _items.length,
        itemBuilder: (_, i) => _VideoTile(video: _items[i], onTap: () => _open(_items[i]), featured: i == 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: widget.inShell,
      title: const Text('ভিডিও'),
      body: _body(),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final FbVideo video;
  final VoidCallback onTap;
  final bool featured;
  const _VideoTile({required this.video, required this.onTap, this.featured = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final v = video;
    final ago = timeAgo(v.created);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.colorScheme.outlineVariant.withAlpha(90)),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(t.brightness == Brightness.dark ? 70 : 22), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: v.square ? 1.0 : 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: Colors.black),
                if (v.thumb.startsWith('http')) Image.network(v.thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54], stops: [0.55, 1])),
                ),
                Center(
                  child: Container(
                    width: featured ? 64 : 54,
                    height: featured ? 64 : 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(235),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(110), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Icon(Icons.play_arrow_rounded, size: featured ? 42 : 36, color: AppConfig.brand),
                  ),
                ),
                if (v.lengthText.isNotEmpty)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withAlpha(170), borderRadius: BorderRadius.circular(8)),
                      child: Text(bn(v.lengthText), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (featured)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(8)),
                      child: const Text('সর্বশেষ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.title.isEmpty ? AppConfig.siteName : v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.35)),
                    const SizedBox(height: 5),
                    Text('${AppConfig.siteName}${ago.isEmpty ? '' : '  •  $ago'}', style: TextStyle(fontSize: 12.5, color: t.colorScheme.outline)),
                  ]),
                ),
                IconButton(
                  tooltip: 'শেয়ার',
                  onPressed: () => shareTo(context, 'fb', v.title.isEmpty ? AppConfig.siteName : v.title, v.permalink),
                  icon: Icon(Icons.share_outlined, color: t.colorScheme.outline),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// লোডিং স্পিনারের বদলে কার্ডের আকারের ঝিলিক-ঝিলিক ধূসর ঘর — অপেক্ষা কম মনে হয়
class _VideoSkeleton extends StatefulWidget {
  const _VideoSkeleton();

  @override
  State<_VideoSkeleton> createState() => _VideoSkeletonState();
}

class _VideoSkeletonState extends State<_VideoSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

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
        Widget box(double h, {double? w}) => Container(height: h, width: w, decoration: BoxDecoration(color: base.withAlpha(a), borderRadius: BorderRadius.circular(12)));
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          children: [
            for (var i = 0; i < 3; i++) ...[
              AspectRatio(aspectRatio: 16 / 9, child: Container(decoration: BoxDecoration(color: base.withAlpha(a), borderRadius: BorderRadius.circular(20)))),
              const SizedBox(height: 10),
              box(16),
              const SizedBox(height: 8),
              box(12, w: 150),
              const SizedBox(height: 22),
            ],
          ],
        );
      },
    );
  }
}
