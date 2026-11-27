import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'fake_stats.dart';
import 'config.dart';
import 'dynamic_ui.dart' show popupOnReload, TabNav;
import 'screens/video_player_screen.dart';
import 'models.dart';
import 'util.dart';
import 'screens/post_screen.dart';

void openPost(BuildContext context, int id) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostScreen(id: id)));
}

/// প্রিমিয়াম কার্ডের বক্স: নরম ছায়া, গোল কোণা, হালকা বর্ডার
BoxDecoration _cardBox(BuildContext context, double radius) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: (dark ? Colors.white : Colors.black).withAlpha(dark ? 20 : 14)),
    boxShadow: [BoxShadow(color: Colors.black.withAlpha(dark ? 60 : 22), blurRadius: 14, offset: const Offset(0, 5))],
  );
}

/// লিস্টের আইটেম নরমভাবে ভেসে ওঠে (fade + হালকা ওপরে ওঠা)
class Reveal extends StatelessWidget {
  final Widget child;
  const Reveal({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c)),
      child: child,
    );
  }
}

/// লোড হওয়ার সময় ঘুরন্ত চাকার বদলে ঝলমলে খালি কার্ড (প্রিমিয়াম অ্যাপের মতো)
class SkeletonList extends StatefulWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h, Color c) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Colors.white : Colors.black;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final c = base.withAlpha((14 + 16 * _a.value).round());
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8),
          children: [
            for (var i = 0; i < widget.count; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(9),
                decoration: _cardBox(context, 18),
                child: Row(children: [
                  Container(width: 118, height: 82, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _bar(double.infinity, 14, c),
                      const SizedBox(height: 8),
                      _bar(180, 14, c),
                      const SizedBox(height: 14),
                      _bar(90, 10, c),
                    ]),
                  ),
                ]),
              ),
          ],
        );
      },
    );
  }
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
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c, Color.lerp(c, Colors.redAccent, 0.55)!]),
          ),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [c.withAlpha(90), c.withAlpha(0)])),
          ),
        ),
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
    return Reveal(child: _byStyle(context, cc, st));
  }

  Widget _byStyle(BuildContext context, CardConf cc, String st) {
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
    const grey = TextStyle(fontSize: 12, color: Colors.grey);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
        if (showCat)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: primary.withAlpha(26), borderRadius: BorderRadius.circular(20), border: Border.all(color: primary.withAlpha(50))),
              child: Text(item.category!.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w700)),
            ),
          ),
        if (cc.showTime)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.access_time, size: 13, color: Colors.grey),
            const SizedBox(width: 3),
            Text(timeAgo(item.date), style: grey),
          ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.visibility_outlined, size: 14, color: Colors.grey),
          const SizedBox(width: 3),
          Text(FakeStats.fmt(FakeStats.views(item.id)), style: grey),
        ]),
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

  Widget _title({double size = 16, int lines = 3}) => SizedBox(
        width: double.infinity,
        child: Text(item.title,
            textAlign: TextAlign.start,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, height: 1.35)),
      );

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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(9),
        decoration: _cardBox(context, cc.radius + 6),
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cc.radius + 4),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(45), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cc.radius + 4),
              child: AspectRatio(aspectRatio: 16 / 9, child: NetImage(item.image)),
            ),
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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardBox(context, cc.radius + 6),
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
    return Reveal(child: InkWell(
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
        SizedBox(
          width: double.infinity,
          child: Text(item.title,
              textAlign: TextAlign.start,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
        ),
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
    ));
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
            SizedBox(
              width: double.infinity,
              child: Text(item.title,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4)),
            ),
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 16, offset: const Offset(0, 7))],
          ),
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
                  SizedBox(
                    width: double.infinity,
                    child: Text(item.title,
                        textAlign: TextAlign.start,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.35)),
                  ),
                ]),
              ),
            ]),
          ),
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

/// হোমের প্রধান খবর: ৫টি খবর ৩ সেকেন্ড পর পর স্লাইড হয়, শেষে আবার প্রথম থেকে ঘুরতে থাকে
class HeroSlider extends StatefulWidget {
  final List<NewsItem> items;
  const HeroSlider(this.items, {super.key});

  @override
  State<HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<HeroSlider> {
  final PageController _pc = PageController();
  Timer? _t;
  int _cur = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _t?.cancel();
    if (widget.items.length < 2) return;
    _t = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_pc.hasClients) _pc.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    if (n == 0) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(builder: (context, c) {
      final cardH = (c.maxWidth - 24) * 10 / 16;
      return Listener(
        onPointerDown: (_) => _t?.cancel(),
        onPointerUp: (_) => _start(),
        onPointerCancel: (_) => _start(),
        child: SizedBox(
          height: cardH + 18,
          child: Stack(children: [
            PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _cur = i % n),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 14),
                child: BigNewsCard(widget.items[i % n]),
              ),
            ),
            if (n > 1)
              Positioned(
                top: 18,
                right: 26,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < n; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: i == _cur ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(color: i == _cur ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(3)),
                      ),
                  ]),
                ),
              ),
          ]),
        ),
      );
    });
  }
}

/// অ্যাডমিন প্যানেলে যে বিজ্ঞাপন (ছবি + লিংক) দেওয়া আছে সেগুলো ঘুরিয়ে ঘুরিয়ে দেখায়।
/// নির্দিষ্ট slot-এর বিজ্ঞাপন না থাকলে অন্য slot-এর বিজ্ঞাপন দেখায়; একটিও না থাকলে কিছুই না।
class AdSlot extends StatelessWidget {
  final String slot;
  final int index;
  const AdSlot({super.key, required this.slot, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final all = AppSettings.current.ads;
    if (all.isEmpty) return const SizedBox.shrink();
    var list = all.where((a) => a.slot == slot).toList();
    if (list.isEmpty) list = all;
    return PromoImage(list[index % list.length], isAd: true);
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
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.bg, Color.lerp(c.bg, Colors.black, 0.28)!]),
            borderRadius: BorderRadius.circular(AppSettings.current.cards.radius + 4),
            boxShadow: [BoxShadow(color: c.bg.withAlpha(90), blurRadius: 12, offset: const Offset(0, 4))],
          ),
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
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video))),
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                NetImage(video.thumb),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black45], stops: [0.5, 1]),
                  ),
                ),
                Center(
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(235),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(90), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                  ),
                ),
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
  /// প্রতি এত আইটেম পরপর একটি বিজ্ঞাপন (০ = নেই)
  final int adEvery;
  /// ট্যাব-কী (যেমন 'latest', 'category:5'); একই ট্যাবে আবার ট্যাপ করলে ওপরে ফিরবে
  final String? tabKey;
  const PagedList({super.key, required this.fetch, required this.pageSize, required this.itemBuilder, this.adEvery = 0, this.tabKey});

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final List<T> _items = [];
  final ScrollController _sc = ScrollController();
  VoidCallback? _unRe;
  int _page = 1;
  bool _loading = false, _done = false, _error = false;

  @override
  void initState() {
    super.initState();
    final tk = widget.tabKey;
    if (tk != null) _unRe = TabNav.onReselect(tk, () => TabNav.scrollTop(_sc));
    _sc.addListener(() {
      if (_sc.position.pixels > _sc.position.maxScrollExtent - 500) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _unRe?.call();
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

  bool get _ads => widget.adEvery > 0 && AppSettings.current.ads.isNotEmpty;
  int get _rows => _ads ? _items.length + _items.length ~/ widget.adEvery : _items.length;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        popupOnReload(context);
        return _refresh();
      },
      child: ListView.builder(
        controller: _sc,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _rows + 1,
        itemBuilder: (context, i) {
          if (i < _rows) {
            final ev = _ads ? widget.adEvery : 0;
            if (ev > 0) {
              if (i % (ev + 1) == ev) return AdSlot(slot: 'list', index: i ~/ (ev + 1));
              return widget.itemBuilder(context, _items[i - i ~/ (ev + 1)]);
            }
            return widget.itemBuilder(context, _items[i]);
          }
          if (_loading) {
            if (_items.isEmpty) return const SizedBox(height: 520, child: SkeletonList());
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
        elevation: 3,
        shadowColor: bg.withAlpha(120),
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

/// হেডার ও ফুটারের লোগো: অ্যাডমিনের লোগো থাকলে সেটি, না থাকলে অ্যাপের ভেতরের লোগো
class AppLogo extends StatelessWidget {
  final double height;
  const AppLogo({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.current;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = (dark && s.logo.darkUrl.isNotEmpty) ? s.logo.darkUrl : s.logo.url;
    if (url.isNotEmpty) return NetImage(url, height: height, fit: BoxFit.contain);
    return Image.asset('assets/logo.png', height: height, fit: BoxFit.contain);
  }
}

class _Partner {
  final String asset, url, title;
  const _Partner(this.asset, this.url, [this.title = '']);
}

const List<_Partner> _partners = [
  _Partner('assets/partners/p1.png', 'https://amarsokalfoundation.org/', 'আমার সকাল ফাউন্ডেশন'),
  _Partner('assets/partners/p2.png', 'https://astechnologiesltd.com/', 'AS Tech'),
  _Partner('assets/partners/p3.png', 'https://njwc.bd/', 'জাতীয় সাংবাদিক কল্যাণ পরিষদ'),
  _Partner('assets/partners/p4.png', 'https://shop.amarsokal24.com/', 'আমার সকাল শপ'),
  _Partner('assets/partners/p5.png', 'https://epaper.amarsokal24.com/', 'ই-পেপার'),
  _Partner('assets/partners/p6.png', 'https://smm.astechnologiesltd.com/', 'AS-SMM'),
  _Partner('assets/partners/p7.png', 'https://en.amarsokal24.com/', 'The Amar Sokal 24'),
  _Partner('assets/partners/p8.png', 'https://institute.amarsokal24.com/', 'আমার সকাল ইনস্টিটিউট'),
];

/// "আমার সকালের অন্যান্য উদ্যোগ" লোগো গ্রিড
class PartnersSection extends StatelessWidget {
  /// compact = সাইড মেনুর ছোট চওড়ায় (ছোট শিরোনাম, কম প্যাডিং)
  final bool compact;
  const PartnersSection({super.key, this.compact = false});

  Widget _card(BuildContext context, _Partner p) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withAlpha(60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppConfig.brand.withAlpha(22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: p.url.isEmpty ? null : () => openInApp(context, p.url, title: p.title),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AspectRatio(aspectRatio: 3.4, child: Image.asset(p.asset, fit: BoxFit.contain)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brand = AppConfig.brand;
    final rows = <Widget>[];
    for (var i = 0; i < _partners.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: _card(context, _partners[i])),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < _partners.length ? _card(context, _partners[i + 1]) : const SizedBox.shrink()),
        ]),
      ));
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 6, compact ? 12 : 14, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 5, height: 22, decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Flexible(
            child: Text('আমার সকালের অন্যান্য উদ্যোগ',
                style: TextStyle(fontSize: compact ? 16 : 19, fontWeight: FontWeight.bold, color: compact ? brand : const Color(0xFF111111))),
          ),
        ]),
        const SizedBox(height: 12),
        ...rows,
      ]),
    );
  }
}

/// নিচের ফুটার (সাদা ব্যাকগ্রাউন্ড): অন্যান্য উদ্যোগ, লোগো, সম্পাদক ও প্রকাশক (বোল্ড), কপিরাইট
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final year = bn(DateTime.now().year);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF3F5FB), Colors.white]),
        border: Border(top: BorderSide(color: AppConfig.brand, width: 4)),
      ),
      child: Column(children: [
        const PartnersSection(),
        const SizedBox(height: 10),
        const Divider(height: 1, indent: 14, endIndent: 14),
        const SizedBox(height: 16),
        if (AppConfig.editorPublisher.isNotEmpty)
          Text('সম্পাদক ও প্রকাশক : ${AppConfig.editorPublisher}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppConfig.brand, height: 1.6)),
        Text('স্বত্ব © ${AppConfig.siteName} $year',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.7)),
      ]),
    );
  }
}
