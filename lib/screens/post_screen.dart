import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../fake_stats.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import '../rewards/read_reward.dart';
import '../saved.dart';
import '../rewards/share_submit_screen.dart';
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
  NewsDetail? _last; // রিফ্রেশের সময় পুরনো লেখা দেখিয়ে রাখতে
  double _fontSize = 20;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    FakeStats.bump(widget.id); // প্রতিবার পড়লে ভিউ ৭ করে বাড়ে
  }

  /// খবরের লেখাকে ৩য় অনুচ্ছেদের পর দুই ভাগ করে (মাঝখানে বিজ্ঞাপন বসাতে); ছোট লেখা ভাগ হয় না
  static List<String> _splitHtml(String html) {
    final low = html.toLowerCase();
    var idx = -1, count = 0, from = 0;
    while (true) {
      final i = low.indexOf('</p>', from);
      if (i < 0) break;
      count++;
      if (count == 3) idx = i + 4;
      from = i + 4;
    }
    if (count < 6 || idx < 0) return [html];
    return [html.substring(0, idx), html.substring(idx)];
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: appHeader(context, back: true),
      body: FutureBuilder<NewsDetail>(
        future: _future,
        builder: (context, snap) => _body(context, snap),
      ),
    );
  }

  /// নিচে টেনে রিফ্রেশ: নিউজটি সার্ভার থেকে আবার আনে (ক্যাশ বাদ দিয়ে)
  Future<void> _refresh() async {
    Api.clearCache();
    try {
      final d = await Api.post(widget.id);
      if (!mounted) return;
      setState(() {
        _last = d;
        _future = Future<NewsDetail>.value(d);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('রিফ্রেশ করা যায়নি, ইন্টারনেট দেখুন')));
    }
  }

  Widget _body(BuildContext context, AsyncSnapshot<NewsDetail> snap) {
    if (snap.hasData) _last = snap.data;
    if (_last == null && snap.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_last == null && (snap.hasError || snap.data == null)) {
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
    final d = _last ?? snap.data!;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final grey = theme.colorScheme.onSurface.withAlpha(150);
    final cat = d.item.category;
    final when = bnDateTime(d.item.date);

    final parts = _splitHtml(d.content);
    final views = FakeStats.views(d.item.id);
    final shares = FakeStats.shares(d.item.id);
    final list = ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
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
      // কতজন পড়েছেন / শেয়ার
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(children: [
          Icon(Icons.visibility_outlined, size: 18, color: grey),
          const SizedBox(width: 5),
          Text('${FakeStats.fmt(views)} জন পড়েছেন', style: TextStyle(fontSize: 14.5, color: grey, fontWeight: FontWeight.w600)),
          const SizedBox(width: 18),
          Icon(Icons.share_outlined, size: 17, color: grey),
          const SizedBox(width: 5),
          Text('${FakeStats.fmt(shares)} শেয়ার', style: TextStyle(fontSize: 14.5, color: grey, fontWeight: FontWeight.w600)),
          Expanded(child: Align(alignment: Alignment.centerRight, child: SaveButton(item: d.item))),
        ]),
      ),
      // শেয়ার বাটন
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: ShareRow(title: d.item.title, link: d.item.link),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: RewardShareButton(postId: d.item.id, title: d.item.title, link: d.item.link),
      ),
      const AdSlot(slot: 'post', index: 0),
      if (d.item.image.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 9, child: NetImage(d.item.image))),
        ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          for (var pi = 0; pi < parts.length; pi++) ...[
            if (pi > 0) const AdSlot(slot: 'post', index: 1),
            Html(
          data: parts[pi],
          style: {
            'body': Style(
              fontFamily: 'Kalpurush',
              textAlign: TextAlign.justify,
              fontSize: FontSize(_fontSize),
              lineHeight: const LineHeight(1.7),
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            'p': Style(margin: Margins.only(bottom: 16), textAlign: TextAlign.justify),
            'a': Style(color: primary, textDecoration: TextDecoration.none),
            'img': Style(width: Width(100, Unit.percent), height: Height.auto(), margin: Margins.only(top: 6, bottom: 6)),
            'blockquote': Style(
              margin: Margins.only(left: 4, top: 8, bottom: 16),
              padding: HtmlPaddings.only(left: 14, top: 4, bottom: 4),
              border: Border(left: BorderSide(color: primary, width: 4)),
              fontStyle: FontStyle.italic,
            ),
            // কনটেন্টের ভেতরের শিরোনাম ওপরের শিরোনামের মতোই (একই ফন্ট, একই সাইজ, বাম থেকে শুরু)
            'h1': Style(
              fontFamily: 'Kalpurush',
              fontSize: FontSize(30),
              fontWeight: FontWeight.w700,
              lineHeight: const LineHeight(1.3),
              textAlign: TextAlign.left,
              margin: Margins.only(top: 6, bottom: 12),
            ),
            'h2': Style(fontSize: FontSize(_fontSize + 4), margin: Margins.only(top: 8, bottom: 12)),
            'h3': Style(fontSize: FontSize(_fontSize + 2), margin: Margins.only(top: 8, bottom: 10)),
          },
          onLinkTap: (url, _, __) {
            if (url != null) openLink(url);
          },
        ),
          ],
        ]),
      ),
      const AdSlot(slot: 'post', index: 2),
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
    // পড়ার অগ্রগতি: ওপরে সরু রঙিন রেখা
    return Stack(children: [
      NotificationListener<ScrollNotification>(
        onNotification: (n) {
          final max = n.metrics.maxScrollExtent;
          if (max > 0) _progress.value = (n.metrics.pixels / max).clamp(0.0, 1.0);
          return false;
        },
        child: RefreshIndicator(onRefresh: _refresh, child: list),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(primary),
          ),
        ),
      ),
      // কয়েন চিপ: খবর পড়ার সময় গোনে ও কয়েন যোগ করে
      Positioned(right: 12, bottom: 16, child: ReadRewardChip(postId: d.item.id)),
    ]);
  }

  /// লেখকের নাম না থাকলে সাইটের নাম
  String s0(BuildContext context) => AppSettings.current.appName;
}
