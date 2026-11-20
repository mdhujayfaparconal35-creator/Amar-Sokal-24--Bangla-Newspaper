import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';

class VideosScreen extends StatelessWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ভিডিও'), centerTitle: true),
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
