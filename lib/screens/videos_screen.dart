import 'package:flutter/material.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../widgets.dart';

class VideosScreen extends StatelessWidget {
  final bool inShell;
  const VideosScreen({super.key, this.inShell = false});

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: inShell,
      title: const Text('ভিডিও'),
      body: PagedList<VideoItem>(
        pageSize: 12,
        fetch: (p) => Api.videos(page: p),
        itemBuilder: (_, v) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: VideoCard(v),
        ),
      ),
    );
  }
}
