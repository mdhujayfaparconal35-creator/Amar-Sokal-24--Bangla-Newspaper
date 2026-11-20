import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'category_screen.dart';

/// খবরের পেজ (কালবেলা অ্যাপের মতো): ওপরে ব্যাক + লোগো + সার্চ/মেনু, তারপর ব্রেডক্রাম্ব,
/// শিরোনাম, লেখক, সময়, শেয়ার বাটন, ছবি, খবর, আরও পড়ুন ও নিচে ফুটার।
class PostScreen extends StatefulWidget {
  final int id;
  const PostScreen({super.key, required this.id});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late Future<NewsDetail> _future = Api.post(widget.id);
  double _fontSize = 21;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        toolbarHeight: kBarHeight,
        titleSpacing: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        title: const AppTitle(),
        actions: headerActions(),
      ),
      body: FutureBuilder<NewsDetail>(
        future: _future,
        builder: (context, snap) => _body(context, snap),
      ),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final grey = theme.colorScheme.onSurface.withAlpha(150);
    final cat = d.item.category;
    final when = bnDateTime(d.item.date);

    return ListView(children: [
      const Divider(height: 1),
      // ব্রেডক্রাম্ব: প্রচ্ছদ » ক্যাটাগরি
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(children: [
          InkWell(
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('প্রচ্ছদ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          if (cat != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('»', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryScreen(category: cat))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(color: primary.withAlpha(24), borderRadius: BorderRadius.circular(20)),
                  child: Text(cat.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
                ),
              ),
            ),
          ],
        ]),
      ),
      // শিরোনাম
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Text(d.item.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.3)),
      ),
      // লেখক
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(children: [
          if (d.reporterImage.isNotEmpty)
            ClipOval(child: NetImage(d.reporterImage, width: 32, height: 32))
          else
            Icon(Icons.person, size: 26, color: theme.colorScheme.onSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [if (d.reporterName.isNotEmpty) d.reporterName else s0(context), if (d.reporterDesignation.isNotEmpty) d.reporterDesignation].join(' • '),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      ),
      // সময় + লেখার আকার
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        child: Row(children: [
          Icon(Icons.unfold_more, size: 24, color: theme.colorScheme.onSurface),
          const SizedBox(width: 6),
          Expanded(child: Text('প্রকাশ : $when', style: TextStyle(fontSize: 15, color: grey))),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'লেখা ছোট',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(14.0, 28.0).toDouble()),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'লেখা বড়',
            icon: const Icon(Icons.text_increase),
            onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(14.0, 28.0).toDouble()),
          ),
        ]),
      ),
      // শেয়ার বাটন
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: ShareRow(title: d.item.title, link: d.item.link),
      ),
      if (d.item.image.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 9, child: NetImage(d.item.image))),
        ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Html(
          data: d.content,
          style: {
            'body': Style(
              fontFamily: 'Kalpurush',
              fontSize: FontSize(_fontSize),
              lineHeight: const LineHeight(1.7),
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            'p': Style(margin: Margins.only(bottom: 16)),
            'a': Style(color: primary, textDecoration: TextDecoration.none),
            'img': Style(width: Width(100, Unit.percent), height: Height.auto(), margin: Margins.only(top: 6, bottom: 6)),
            'blockquote': Style(
              margin: Margins.only(left: 4, top: 8, bottom: 16),
              padding: HtmlPaddings.only(left: 14, top: 4, bottom: 4),
              border: Border(left: BorderSide(color: primary, width: 4)),
              fontStyle: FontStyle.italic,
            ),
            'h2': Style(fontSize: FontSize(_fontSize + 4), margin: Margins.only(top: 8, bottom: 12)),
            'h3': Style(fontSize: FontSize(_fontSize + 2), margin: Margins.only(top: 8, bottom: 10)),
          },
          onLinkTap: (url, _, __) {
            if (url != null) openLink(url);
          },
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: ShareRow(title: d.item.title, link: d.item.link),
      ),
      if (d.related.isNotEmpty) ...[
        const SectionTitle('আরও পড়ুন'),
        for (final n in d.related) NewsCard(n),
      ],
      const AppFooter(),
    ]);
  }

  /// লেখকের নাম না থাকলে সাইটের নাম
  String s0(BuildContext context) => AppSettings.current.appName;
}
