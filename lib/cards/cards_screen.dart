import 'package:cached_network_image/cached_network_image.dart';
import '../fake_stats.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../dynamic_ui.dart';
import '../rewards/reward_api.dart';
import '../rewards/reward_screens.dart';
import '../util.dart';
import 'cards_api.dart';
import 'fake_comments.dart';

/// "ফটো কার্ড" ট্যাব: ফেসবুক পেজের নিউজ ফটো কার্ড (পেজের কমেন্টের লিংকসহ); অ্যাপেই লাইক ও কমেন্ট করা যায়।
class PhotoCardsScreen extends StatefulWidget {
  final bool inShell;
  const PhotoCardsScreen({super.key, this.inShell = false});

  @override
  State<PhotoCardsScreen> createState() => _PhotoCardsScreenState();
}

class _PhotoCardsScreenState extends State<PhotoCardsScreen> {
  final List<PhotoCard> _items = [];
  final ScrollController _sc = ScrollController();
  VoidCallback? _unRe;
  String _next = '';
  bool _loading = false, _more = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _unRe = TabNav.onReselect('photocard', () => TabNav.scrollTop(_sc));
    _sc.addListener(() {
      if (_sc.hasClients && _sc.position.pixels > _sc.position.maxScrollExtent - 600) _loadMore();
    });
    _init();
  }

  @override
  void dispose() {
    _unRe?.call();
    _sc.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final c = await CardsApi.cached();
    if (c != null && mounted && _items.isEmpty) setState(() => _items.addAll(c.items));
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final p = await CardsApi.list();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(p.items);
        _next = p.next;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is RewardError ? e.message : 'লোড করা যায়নি, ইন্টারনেট দেখুন');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_more || _loading || _next.isEmpty) return;
    setState(() => _more = true);
    try {
      final p = await CardsApi.list(after: _next);
      if (!mounted) return;
      setState(() {
        final have = _items.map((e) => e.id).toSet();
        _items.addAll(p.items.where((e) => !have.contains(e.id)));
        _next = p.next;
      });
      // এই পাতায় ফটো কার্ড না থাকলে (শুধু অন্য ধরনের পোস্ট) পরেরটা আনে
      if (p.items.isEmpty && _next.isNotEmpty && mounted) {
        _more = false;
        _loadMore();
        return;
      }
    } catch (_) {
      // নিঃশব্দে; আবার স্ক্রল করলে চেষ্টা করবে
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_items.isEmpty) {
      body = ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        SizedBox(
          height: 420,
          child: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_error.isEmpty ? 'কোনো ফটো কার্ড পাওয়া যায়নি' : _error, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _refresh, child: const Text('আবার চেষ্টা করুন')),
                    ]),
                  ),
          ),
        ),
      ]);
    } else {
      body = ListView.builder(
        controller: _sc,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i < _items.length) return _CardTile(key: ValueKey(_items[i].id), card: _items[i]);
          if (_more) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          return const SizedBox(height: 28);
        },
      );
    }
    return ShellScaffold(
      inShell: widget.inShell,
      title: const Text('ফটো কার্ড'),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

void _needLogin(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('$what করতে আগে লগইন করুন'),
      action: SnackBarAction(label: 'লগইন', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardScreen()))),
    ));
}

class _CardTile extends StatefulWidget {
  final PhotoCard card;
  const _CardTile({super.key, required this.card});

  @override
  State<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<_CardTile> {
  bool _busy = false;
  PhotoCard get c => widget.card;

  Future<void> _like() async {
    if (!RewardApi.loggedIn.value) return _needLogin(context, 'লাইক');
    if (_busy) return;
    _busy = true;
    final was = c.liked;
    setState(() {
      c.liked = !was;
      c.likes += was ? -1 : 1;
    });
    try {
      final j = await CardsApi.like(c.id);
      if (mounted) {
        setState(() {
          c.liked = j['liked'] == true;
          c.likes = ri(j['likes']);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          c.liked = was;
          c.likes += was ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is RewardError ? e.message : 'লাইক দেওয়া যায়নি')));
      }
    } finally {
      _busy = false;
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CommentsSheet(card: c, onCount: (n) => setState(() => c.comments = n)),
    );
  }

  void _viewImage() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: CachedNetworkImage(imageUrl: c.image, fit: BoxFit.contain, placeholder: (_, __) => const CircularProgressIndicator()),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final grey = t.colorScheme.onSurface.withAlpha(150);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.colorScheme.outline.withAlpha(50)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            ClipOval(child: Image.asset('assets/logo.png', width: 34, height: 34)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('আমার সকাল ২৪', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(timeAgo(c.created), style: TextStyle(fontSize: 12.5, color: grey)),
              ]),
            ),
          ]),
        ),
        if (c.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: LinkText(c.caption, style: const TextStyle(fontSize: 16.5, height: 1.45, fontWeight: FontWeight.w600)),
          ),
        GestureDetector(
          onTap: _viewImage,
          child: CachedNetworkImage(
            imageUrl: c.image,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            placeholder: (_, __) => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
            errorWidget: (_, __, ___) => const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image_outlined, size: 36))),
          ),
        ),
        if (c.pageComment.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: t.colorScheme.primary.withAlpha(16), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('কমেন্ট', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: t.colorScheme.primary)),
              const SizedBox(height: 4),
              LinkText(c.pageComment, style: const TextStyle(fontSize: 15, height: 1.45)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Row(children: [
            TextButton.icon(
              onPressed: _like,
              icon: Icon(c.liked ? Icons.favorite : Icons.favorite_border, color: c.liked ? Colors.red.shade600 : grey),
              label: Text(FakeStats.fmt(FakeStats.cardLikes(c.id) + (c.likes < 0 ? 0 : c.likes)), style: TextStyle(color: c.liked ? Colors.red.shade600 : grey, fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: _openComments,
              icon: Icon(Icons.mode_comment_outlined, color: grey),
              label: Text((c.comments + FakeComments.baseCount(c.id)) > 0 ? '${bn(c.comments + FakeComments.baseCount(c.id))} কমেন্ট' : 'কমেন্ট', style: TextStyle(color: grey, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'শেয়ার',
              icon: Icon(Icons.share_outlined, color: grey),
              onPressed: () {
                final first = c.caption.split('\n').first;
                Share.share('$first\n${c.permalink}'.trim());
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final PhotoCard card;
  final void Function(int) onCount;
  const _CommentsSheet({required this.card, required this.onCount});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final List<CardComment> _list = [];
  late final List<CardComment> _fake = FakeComments.forCard(widget.card);
  final _ctrl = TextEditingController();
  int _page = 1;
  bool _loading = true, _done = false, _sending = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await CardsApi.comments(widget.card.id, _page);
      if (!mounted) return;
      setState(() {
        _list.addAll(r);
        if (r.length < 20) _done = true;
        _page++;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is RewardError ? e.message : 'কমেন্ট লোড করা যায়নি');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (!RewardApi.loggedIn.value) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _sending = true);
    try {
      final j = await CardsApi.addComment(widget.card.id, text);
      if (!mounted) return;
      final cm = CardComment.fromJson(Map<String, dynamic>.from(j['comment'] as Map));
      setState(() {
        _list.insert(0, cm);
        _ctrl.clear();
      });
      widget.onCount(ri(j['total']));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is RewardError ? e.message : 'কমেন্ট করা যায়নি')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(CardComment c) async {
    try {
      await CardsApi.deleteComment(c.id);
      if (!mounted) return;
      setState(() => _list.remove(c));
      widget.onCount((widget.card.comments - 1).clamp(0, 1 << 30).toInt());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final grey = t.colorScheme.onSurface.withAlpha(150);
    final logged = RewardApi.loggedIn.value;
    // আসল কমেন্ট আগে, সব আসল কমেন্ট দেখানো শেষ হলে তার নিচে ডেমো কমেন্ট
    final all = <CardComment>[..._list, if (_done) ..._fake];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(children: [
              const Expanded(child: Text('কমেন্ট', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: all.isEmpty
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error.isEmpty ? 'এখনো কোনো কমেন্ট নেই। প্রথম কমেন্টটি আপনিই করুন।' : _error, textAlign: TextAlign.center, style: TextStyle(color: grey)),
                          ),
                  )
                : ListView.builder(
                    itemCount: all.length + 1,
                    itemBuilder: (context, i) {
                      if (i == all.length) {
                        if (_done) return const SizedBox(height: 12);
                        return Center(child: TextButton(onPressed: _loading ? null : _load, child: Text(_loading ? 'লোড হচ্ছে…' : 'আরও কমেন্ট দেখুন')));
                      }
                      final cm = all[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(radius: 16, backgroundColor: t.colorScheme.primary.withAlpha(30), child: Text(cm.name.isEmpty ? '?' : cm.name.characters.first, style: TextStyle(color: t.colorScheme.primary, fontWeight: FontWeight.w800))),
                        title: Row(children: [
                          Flexible(child: Text(cm.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                          const SizedBox(width: 8),
                          Text(timeAgo(cm.created), style: TextStyle(fontSize: 11.5, color: grey)),
                        ]),
                        subtitle: LinkText(cm.text, style: const TextStyle(fontSize: 14.5, height: 1.4)),
                        trailing: cm.mine ? IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.delete_outline, size: 20, color: grey), onPressed: () => _delete(cm)) : null,
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
            child: logged
                ? Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(hintText: 'কমেন্ট লিখুন…', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)) : Icon(Icons.send_rounded, color: t.colorScheme.primary),
                    ),
                  ])
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardScreen()));
                      },
                      child: const Text('কমেন্ট করতে লগইন করুন'),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// লেখার ভেতরের http/https লিংক ট্যাপ করা যায় (অ্যাপের ভেতরেই খোলে)
class LinkText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const LinkText(this.text, {super.key, this.style});

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final List<TapGestureRecognizer> _rec = [];
  static final RegExp _url = RegExp(r'https?://[^\s<>"]+');

  @override
  void dispose() {
    for (final r in _rec) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _rec) {
      r.dispose();
    }
    _rec.clear();
    final base = (widget.style ?? DefaultTextStyle.of(context).style);
    final link = base.copyWith(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline, fontWeight: FontWeight.w700);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _url.allMatches(widget.text)) {
      if (m.start > last) spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      var u = m.group(0)!;
      // শেষে লেগে থাকা দাঁড়ি/কমা লিংকের অংশ নয়
      var tail = '';
      while (u.isNotEmpty && '.,;:!?)।'.contains(u[u.length - 1])) {
        tail = u[u.length - 1] + tail;
        u = u.substring(0, u.length - 1);
      }
      final rec = TapGestureRecognizer()..onTap = () => openLink(u);
      _rec.add(rec);
      spans.add(TextSpan(text: u, style: link, recognizer: rec));
      if (tail.isNotEmpty) spans.add(TextSpan(text: tail));
      last = m.end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
