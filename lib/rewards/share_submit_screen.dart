import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../util.dart';
import 'reward_api.dart';
import 'reward_screens.dart';

/// খবরের পেজে "শেয়ার করে কয়েন নিন" বাটন
class RewardShareButton extends StatelessWidget {
  final int postId;
  final String title;
  final String link;
  const RewardShareButton({super.key, required this.postId, required this.title, required this.link});

  @override
  Widget build(BuildContext context) {
    if (ri(RewardApi.cfg['open']) == 0) return const SizedBox.shrink();
    final coin = ri(RewardApi.cfg['share_coin']);
    return OutlinedButton.icon(
      icon: Icon(Icons.card_giftcard, color: Colors.amber.shade800),
      label: Text('ফেসবুকে শেয়ার করে ${bn(coin)} কয়েন নিন'),
      onPressed: () {
        final nav = Navigator.of(context);
        if (!RewardApi.loggedIn.value) {
          nav.push(MaterialPageRoute(builder: (_) => const RewardScreen()));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => ShareSubmitScreen(postId: postId, title: title, link: link)));
        }
      },
    );
  }
}

/// ধাপে ধাপে: ১) ফেসবুকে শেয়ার ২) পেজ ফলো ৩) দুটি স্ক্রিনশট বেছে জমা
class ShareSubmitScreen extends StatefulWidget {
  final int postId;
  final String title;
  final String link;
  const ShareSubmitScreen({super.key, required this.postId, required this.title, required this.link});

  @override
  State<ShareSubmitScreen> createState() => _ShareSubmitScreenState();
}

class _ShareSubmitScreenState extends State<ShareSubmitScreen> {
  String? _shareShot;
  String? _followShot;
  bool _busy = false;

  Future<void> _pick(bool share) async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1080, imageQuality: 80);
      if (x == null) return;
      if (await x.length() > 3 * 1024 * 1024) {
        rewardSnack(context, 'ছবি সর্বোচ্চ ৩ MB হতে পারবে।');
        return;
      }
      setState(() {
        if (share) {
          _shareShot = x.path;
        } else {
          _followShot = x.path;
        }
      });
    } catch (_) {
      rewardSnack(context, 'ছবি বাছাই করা যায়নি।');
    }
  }

  Future<void> _submit() async {
    if (_shareShot == null || _followShot == null) return;
    setState(() => _busy = true);
    try {
      final j = await RewardApi.submitShare(widget.postId, _shareShot!, _followShot!);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 44),
          content: Text('${j['message'] ?? 'জমা হয়েছে।'}', textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('ঠিক আছে'))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on RewardError catch (e) {
      rewardSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _step(int n, String title, String sub, Widget action) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 13, backgroundColor: cs.primary, child: Text(bn(n), style: const TextStyle(color: Colors.white, fontSize: 14))),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ]),
          if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6, left: 36), child: Text(sub, style: const TextStyle(fontSize: 13.5))),
          const SizedBox(height: 10),
          action,
        ]),
      ),
    );
  }

  Widget _shot(String? path, String label, bool share) {
    return Row(children: [
      if (path != null)
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), width: 64, height: 90, fit: BoxFit.cover))
      else
        Container(width: 64, height: 90, decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image_outlined)),
      const SizedBox(width: 12),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _pick(share),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(path == null ? label : 'ছবি বদলান'),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final coin = ri(RewardApi.cfg['share_coin']);
    final page = '${RewardApi.cfg['fb_page_url'] ?? ''}'.trim();
    final ready = _shareShot != null && _followShot != null && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('শেয়ার করে কয়েন নিন')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        _step(
          1,
          'ফেসবুকে শেয়ার করুন',
          'খবরটি আপনার ফেসবুকে পোস্ট করুন, তারপর পোস্টের স্ক্রিনশট নিন।',
          FilledButton.icon(onPressed: () => shareTo(context, 'fb', widget.title, widget.link), icon: const Icon(Icons.facebook), label: const Text('ফেসবুকে শেয়ার')),
        ),
        _step(
          2,
          'আমাদের ফেসবুক পেজ ফলো করুন',
          page.isEmpty ? 'পেজ ফলো করে ফলো অবস্থার স্ক্রিনশট নিন।' : 'পেজটি ফলো করে "Following" দেখা যায় এমন স্ক্রিনশট নিন।',
          page.isEmpty ? const SizedBox.shrink() : OutlinedButton.icon(onPressed: () => openLink(page), icon: const Icon(Icons.thumb_up_alt_outlined), label: const Text('পেজ খুলুন')),
        ),
        _step(3, 'স্ক্রিনশট জমা দিন', 'দুটি আলাদা স্ক্রিনশট লাগবে (JPG/PNG, সর্বোচ্চ ৩ MB)। একই ছবি আবার জমা নেওয়া হয় না।', Column(children: [
          _shot(_shareShot, 'শেয়ারের স্ক্রিনশট', true),
          const SizedBox(height: 10),
          _shot(_followShot, 'পেজ ফলোর স্ক্রিনশট', false),
        ])),
        const SizedBox(height: 4),
        FilledButton(
          onPressed: ready ? _submit : null,
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : Text('জমা দিন (${bn(coin)} কয়েন)'),
        ),
        const SizedBox(height: 8),
        const Text('অ্যাডমিন যাচাই করার পর কয়েন যোগ হবে। ভুয়া বা পুরনো স্ক্রিনশট দিলে অ্যাকাউন্ট বন্ধ হতে পারে।', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5)),
      ]),
    );
  }
}
