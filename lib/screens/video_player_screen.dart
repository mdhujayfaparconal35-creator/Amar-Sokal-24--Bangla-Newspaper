import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../api.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// ভিডিও অ্যাপের ভেতরেই চলে (ইউটিউব প্লেয়ার, ফুলস্ক্রিন বাটনসহ)। নিচে শেয়ার ও আরও ভিডিও।
class VideoPlayerScreen extends StatefulWidget {
  final VideoItem video;
  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final String _id = youtubeId(widget.video.youtube);
  YoutubePlayerController? _c;
  late final Future<List<VideoItem>> _more = Api.videos(page: 1);

  @override
  void initState() {
    super.initState();
    if (_id.isNotEmpty) {
      _c = YoutubePlayerController.fromVideoId(
        videoId: _id,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true),
      );
    }
  }

  @override
  void dispose() {
    _c?.close();
    super.dispose();
  }

  Widget _page(BuildContext context, Widget player) {
    final v = widget.video;
    return Scaffold(
      appBar: AppBar(title: const Text('ভিডিও')),
      body: ListView(children: [
        player,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(v.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.35)),
        ),
        if (v.date.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(bnDateTime(v.date), style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor)),
          ),
        if (_id.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: ShareRow(title: v.title, link: 'https://www.youtube.com/watch?v=$_id'),
          ),
        const SectionTitle('আরও ভিডিও'),
        FutureBuilder<List<VideoItem>>(
          future: _more,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            final list = (snap.data ?? const <VideoItem>[]).where((e) => e.id != v.id).toList();
            return Column(children: [
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: VideoCard(e),
                ),
            ]);
          },
        ),
        const AppFooter(),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return _page(
        context,
        const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(color: Colors.black, child: Center(child: Text('ভিডিওটি চালানো যাচ্ছে না', style: TextStyle(color: Colors.white))))),
      );
    }
    return YoutubePlayerScaffold(
      controller: c,
      aspectRatio: 16 / 9,
      builder: (context, player) => _page(context, player),
    );
  }
}
