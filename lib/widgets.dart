import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'config.dart';
import 'models.dart';
import 'util.dart';
import 'screens/post_screen.dart';

void openPost(BuildContext context, int id) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostScreen(id: id)));
}

class NetImage extends StatelessWidget {
  final String url;
  final double? width, height;
  final BoxFit fit;
  const NetImage(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: width,
      height: height,
      color: Colors.black12,
      child: const Icon(Icons.image_outlined, color: Colors.black38),
    );
    if (url.isEmpty) return ph;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Container(width: width, height: height, color: Colors.black12),
      errorWidget: (_, __, ___) => ph,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 10),
      child: Row(children: [
        Container(
          width: 5,
          height: 24,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1.5, color: c.withAlpha(50))),
      ]),
    );
  }
}

/// নিউজ কার্ড: ধরন (small/compact/big/overlay) অ্যাডমিন থেকে ঠিক হয়।
/// [style] না দিলে অ্যাডমিনের সাধারণ কার্ড সেটিং ব্যবহার হয়।
class NewsCard extends StatelessWidget {
  final NewsItem item;
  final String? style;
  const NewsCard(this.item, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final cc = AppSettings.current.cards;
    final st = (style == null || style!.isEmpty) ? cc.style : style!;
    switch (st) {
      case 'overlay':
        return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: BigNewsCard(item));
      case 'big':
      case 'grid': // এককভাবে (যেমন তালিকা পেজে) গ্রিড কার্ড = বড় কার্ড; হোমে দুই কলামে সাজে
        return _bigCard(context, cc);
      case 'compact':
        return _compactCard(context, cc);
      default:
        return _smallCard(context, cc);
    }
  }

  Widget _meta(BuildContext context, CardConf cc) {
    final primary = Theme.of(context).colorScheme.primary;
    final showCat = cc.showCategory && item.category != null;
    if (!showCat && !cc.showTime) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        if (showCat)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: primary.withAlpha(24), borderRadius: BorderRadius.circular(20)),
              child: Text(item.category!.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w700)),
            ),
          ),
        if (showCat && cc.showTime) const SizedBox(width: 8),
        if (cc.showTime) Text(timeAgo(item.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }

  Widget _excerpt(CardConf cc) {
    if (!cc.showExcerpt || item.excerpt.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(item.excerpt,
          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.3)),
    );
  }

  Widget _title({double size = 16, int lines = 3}) => Text(item.title,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, height: 1.35));

  Widget _smallCard(BuildContext context, CardConf cc) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(cc.radius + 4),
      child: NetImage(item.image, width: 118, height: 82),
    );
    final text = Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(),
        _excerpt(cc),
        _meta(context, cc),
      ]),
    );
    return InkWell(
      onTap: () => openPost(context, item.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(50)))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cc.imageRight ? [text, const SizedBox(width: 12), image] : [image, const SizedBox(width: 12), text],
        ),
      ),
    );
  }

  Widget _bigCard(BuildContext context, CardConf cc) {
    return InkWell(
      onTap: () => openPost(context, item.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(cc.radius),
            child: AspectRatio(aspectRatio: 16 / 9, child: NetImage(item.image)),
          ),
          const SizedBox(height: 8),
          _title(size: 18),
          _excerpt(cc),
          _meta(context, cc),
        ]),
      ),
    );
  }

  Widget _compactCard(BuildContext context, CardConf cc) {
    return InkWell(
      onTap: () => openPost(context, item.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(60)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(size: 16, lines: 2),
          _excerpt(cc),
          _meta(context, cc),
        ]),
      ),
    );
  }
}

/// ওয়েবসাইটের মতো দুই কলামের গ্রিডের একটি কার্ড: ওপরে ছবি, নিচে বোল্ড শিরোনাম
class GridCard extends StatelessWidget {
  final NewsItem item;
  const GridCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final cc = AppSettings.current.cards;
    final primary = Theme.of(context).colorScheme.primary;
    final showCat = cc.showCategory && item.category != null;
    return InkWell(
      onTap: () => openPost(context, item.id),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cc.radius + 4),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cc.radius + 4),
            child: AspectRatio(aspectRatio: 16 / 10, child: NetImage(item.image)),
          ),
        ),
        const SizedBox(height: 10),
        Text(item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
        if (showCat || cc.showTime)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              if (showCat)
                Flexible(
                  child: Text(item.category!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600)),
                ),
              if (showCat && cc.showTime) const SizedBox(width: 8),
              if (cc.showTime) Text(timeAgo(item.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
      ]),
    );
  }
}

/// খবরগুলো দুই কলামের গ্রিডে সাজায়
class NewsGrid extends StatelessWidget {
  final List<NewsItem> items;
  const NewsGrid(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: GridCard(items[i])),
          const SizedBox(width: 12),
          Expanded(child: i + 1 < items.length ? GridCard(items[i + 1]) : const SizedBox.shrink()),
        ]),
      ));
    }
    return Column(children: rows);
  }
}

/// প্রধান খবর (ওয়েবসাইট স্টাইল): পুরো প্রস্থের ছবি, নিচে বড় বোল্ড শিরোনাম
class HeroBelowCard extends StatelessWidget {
  final NewsItem item;
  const HeroBelowCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final cc = AppSettings.current.cards;
    final primary = Theme.of(context).colorScheme.primary;
    final showCat = cc.showCategory && item.category != null;
    return InkWell(
      onTap: () => openPost(context, item.id),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 16 / 10, child: NetImage(item.image)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, height: 1.3)),
            if (showCat || cc.showTime)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  if (showCat)
                    Text(item.category!.name, style: TextStyle(fontSize: 13, color: primary, fontWeight: FontWeight.w600)),
                  if (showCat && cc.showTime) const SizedBox(width: 8),
                  if (cc.showTime) Text(timeAgo(item.date), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// বড় কার্ড: পুরো প্রস্থের ছবির ওপর শিরোনাম (প্রধান খবর / overlay ধরন)
class BigNewsCard extends StatelessWidget {
  final NewsItem item;
  const BigNewsCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final radius = AppSettings.current.theme.radius + 6;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => openPost(context, item.id),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(fit: StackFit.expand, children: [
              NetImage(item.image),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54, Color(0xF2000000)],
                    stops: [0.35, 0.7, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (item.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(item.category!.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 6),
                  Text(item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.3)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ব্যানার/বিজ্ঞাপনের ছবি (সার্ভার থেকে আসা https ছবি)। ট্যাপ করলে লিংক খোলে।
class PromoImage extends StatelessWidget {
  final PromoItem item;
  final bool isAd;
  const PromoImage(this.item, {super.key, this.isAd = false});

  @override
  Widget build(BuildContext context) {
    final r = AppSettings.current.cards.radius;
    final image = item.ratio > 0
        ? AspectRatio(aspectRatio: item.ratio, child: NetImage(item.image))
        : CachedNetworkImage(
            imageUrl: item.image,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            placeholder: (_, __) => Container(height: 100, color: Colors.black12),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: item.link.isEmpty ? null : () => openLink(item.link),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: Stack(children: [
            image,
            if (isAd)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: const Text('বিজ্ঞাপন', style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// লাইভ টিভি / ই-পেপার কার্ড
class LinkCard extends StatelessWidget {
  final LinkBox box;
  final IconData icon;
  const LinkCard(this.box, {super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final t = AppSettings.current.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () => openLink(box.url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(t.radius),
          child: Stack(alignment: Alignment.bottomLeft, children: [
            if (box.image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: box.image,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                placeholder: (_, __) => Container(height: 120, color: t.secondary),
                errorWidget: (_, __, ___) => Container(height: 80, color: t.secondary),
              )
            else
              Container(height: 80, width: double.infinity, color: t.secondary),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
              ),
              child: Row(children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(box.title,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class BreakItem {
  final String text;
  final int? postId;
  const BreakItem(this.text, [this.postId]);
}

/// ব্রেকিং নিউজ বার: লেখাগুলো একটার পর একটা বদলায় (ট্যাপ করলে নিউজ খোলে, যদি নিউজের আইডি থাকে)
class BreakingBar extends StatefulWidget {
  final BreakingConf conf;
  final List<BreakItem> items;
  const BreakingBar({super.key, required this.conf, required this.items});

  @override
  State<BreakingBar> createState() => _BreakingBarState();
}

class _BreakingBarState extends State<BreakingBar> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.items.length < 2) return;
      setState(() => _i = (_i + 1) % widget.items.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final c = widget.conf;
    final it = widget.items[_i % widget.items.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: it.postId == null ? null : () => openPost(context, it.postId!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(AppSettings.current.cards.radius)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
              child: Text(c.label, style: TextStyle(color: c.color, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Text(it.text,
                    key: ValueKey('$_i-${it.text}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.color, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  final VideoItem video;
  final double? width;
  const VideoCard(this.video, {super.key, this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openYoutube(video.youtube),
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                NetImage(video.thumb),
                const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3)),
        ]),
      ),
    );
  }
}

/// পেজ ধরে ধরে লোড হওয়া তালিকা (নিচে গেলে পরের পেজ আসে)
class PagedList<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) fetch;
  final int pageSize;
  final Widget Function(BuildContext, T) itemBuilder;
  const PagedList({super.key, required this.fetch, required this.pageSize, required this.itemBuilder});

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final List<T> _items = [];
  final ScrollController _sc = ScrollController();
  int _page = 1;
  bool _loading = false, _done = false, _error = false;

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (_sc.position.pixels > _sc.position.maxScrollExtent - 500) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final r = await widget.fetch(_page);
      if (!mounted) return;
      setState(() {
        _items.addAll(r);
        if (r.length < widget.pageSize) _done = true;
        _page++;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 1;
      _done = false;
      _error = false;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _sc,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i < _items.length) return widget.itemBuilder(context, _items[i]);
          if (_loading) {
            return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          }
          if (_error) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(children: [
                  const Text('লোড করা যায়নি, ইন্টারনেট দেখুন'),
                  TextButton(onPressed: _load, child: const Text('আবার চেষ্টা করুন')),
                ]),
              ),
            );
          }
          if (_items.isEmpty && _done) {
            return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('কিছু পাওয়া যায়নি')));
          }
          return const SizedBox(height: 24);
        },
      ),
    );
  }
}


/// খবরের শেয়ার বাটন সারি (কালবেলার মতো গোল রঙিন বাটন)
class ShareRow extends StatelessWidget {
  final String title, link;
  const ShareRow({super.key, required this.title, required this.link});

  Widget _b(BuildContext context, Color bg, String where, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => shareTo(context, where, title, link),
          child: SizedBox(width: 42, height: 42, child: Center(child: child)),
        ),
      ),
    );
  }

  Widget _t(String s, {double size = 18}) =>
      Text(s, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size, height: 1));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _b(context, const Color(0xFF3B5998), 'fb', _t('f', size: 22)),
        _b(context, const Color(0xFF0A7CFF), 'messenger', const Icon(Icons.messenger_outline, color: Colors.white, size: 21)),
        _b(context, const Color(0xFF25D366), 'whatsapp', const Icon(Icons.call, color: Colors.white, size: 21)),
        _b(context, Colors.black, 'x', _t('X', size: 17)),
        _b(context, const Color(0xFF0077B5), 'linkedin', _t('in', size: 16)),
        _b(context, const Color(0xFF1B5E20), 'copy', const Icon(Icons.copy_rounded, color: Colors.white, size: 19)),
      ]),
    );
  }
}

/// নিচের ফুটার: সম্পাদক, প্রকাশক ও কপিরাইট (নাম ফাঁকা থাকলে ওই লাইন বাদ)
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14.5, height: 1.7, color: Colors.white70);
    final year = bn(DateTime.now().year);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
      decoration: const BoxDecoration(color: AppConfig.brand),
      child: Column(children: [
        ClipOval(child: Image.asset('assets/logo.png', width: 54, height: 54)),
        const SizedBox(height: 10),
        if (AppConfig.editorPublisher.isNotEmpty)
          Text('সম্পাদক ও প্রকাশক : ${AppConfig.editorPublisher}', style: style, textAlign: TextAlign.center),
        Text('স্বত্ব © ${AppConfig.siteName} $year', style: style, textAlign: TextAlign.center),
      ]),
    );
  }
}
