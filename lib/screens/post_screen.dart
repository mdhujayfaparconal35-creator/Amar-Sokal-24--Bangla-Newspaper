import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';

class PostScreen extends StatefulWidget {
  final int id;
  const PostScreen({super.key, required this.id});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late Future<NewsDetail> _future = Api.post(widget.id);
  double _fontSize = 18;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NewsDetail>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.text_decrease),
                onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(14.0, 28.0).toDouble()),
              ),
              IconButton(
                icon: const Icon(Icons.text_increase),
                onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(14.0, 28.0).toDouble()),
              ),
              if (d != null)
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => Share.share('${d.item.title}\n${d.item.link}'),
                ),
            ],
          ),
          body: _body(context, snap),
        );
      },
    );
  }

  Widget _body(BuildContext context, AsyncSnapshot<NewsDetail> snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError || snap.data == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('নিউজটি লোড করা যায়নি'),
          TextButton(
            onPressed: () => setState(() => _future = Api.post(widget.id)),
            child: const Text('আবার চেষ্টা করুন'),
          ),
        ]),
      );
    }
    final d = snap.data!;
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(children: [
      if (d.item.image.isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: NetImage(d.item.image)),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (d.item.category != null)
            Text(d.item.category!.name, style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(d.item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.35)),
          const SizedBox(height: 12),
          Row(children: [
            if (d.reporterImage.isNotEmpty)
              ClipOval(child: NetImage(d.reporterImage, width: 40, height: 40))
            else
              const CircleAvatar(radius: 20, child: Icon(Icons.person)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (d.reporterName.isNotEmpty) Text(d.reporterName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  [if (d.reporterDesignation.isNotEmpty) d.reporterDesignation, timeAgo(d.item.date)].join(' • '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ]),
            ),
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Html(
          data: d.content,
          style: {
            'body': Style(fontSize: FontSize(_fontSize), lineHeight: const LineHeight(1.7), margin: Margins.zero, padding: HtmlPaddings.zero),
            'img': Style(width: Width(100, Unit.percent), height: Height.auto()),
          },
          onLinkTap: (url, _, __) {
            if (url != null) openLink(url);
          },
        ),
      ),
      if (d.related.isNotEmpty) ...[
        const SectionTitle('আরও পড়ুন'),
        for (final n in d.related) NewsCard(n),
      ],
      const SizedBox(height: 32),
    ]);
  }
}
