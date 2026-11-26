import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'notifications.dart' show appNavKey;
import 'screens/web_page_screen.dart';

const _en = '0123456789';
const _bn = '০১২৩৪৫৬৭৮৯';

String bn(Object v) {
  final s = v.toString();
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _en.indexOf(ch);
    b.write(i >= 0 ? _bn[i] : ch);
  }
  return b.toString();
}

String timeAgo(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = DateTime.now().toUtc().difference(d.toUtc());
  if (diff.inMinutes < 1) return 'এইমাত্র';
  if (diff.inMinutes < 60) return '${bn(diff.inMinutes)} মিনিট আগে';
  if (diff.inHours < 24) return '${bn(diff.inHours)} ঘণ্টা আগে';
  if (diff.inDays < 30) return '${bn(diff.inDays)} দিন আগে';
  final l = d.toLocal();
  return '${bn(l.day)}/${bn(l.month)}/${bn(l.year)}';
}

Future<void> openYoutube(String id) async {
  if (id.isEmpty) return;
  await openLink('https://www.youtube.com/watch?v=$id');
}

/// লিংক খোলে (ব্রাউজারে)। ভুল/https নয় এমন লিংক উপেক্ষা করে।
Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' && uri.scheme != 'http') return;
  // সব লিংক অ্যাপের ভেতরেই (অ্যাপের হেডারসহ) খোলে; অ্যাপ-পেজ তৈরি না থাকলে তবেই বাইরের ব্রাউজার
  final nav = appNavKey.currentState;
  if (nav != null) {
    nav.push(MaterialPageRoute(builder: (_) => WebPageScreen(url: url)));
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok) await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// লিংক অ্যাপের ভেতরেই খোলে (অ্যাপের নিজস্ব হেডার সহ; ওয়েবসাইটের হেডার-ফুটার লুকানো)
void openInApp(BuildContext context, String url, {String title = ''}) {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebPageScreen(url: url, title: title)));
}

const _months = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'];

/// "২০ নভেম্বর ২০২৬, ০১:১৮ পিএম" (সার্ভারের দেওয়া সময়ই দেখায়, জোন বদলায় না)
String bnDateTime(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final hh = h12.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${bn(d.day)} ${_months[d.month - 1]} ${bn(d.year)}, ${bn('$hh:$mm')} ${d.hour < 12 ? 'এএম' : 'পিএম'}';
}

/// অন্য অ্যাপে (ফেসবুক, হোয়াটসঅ্যাপ ইত্যাদি) খোলে; না পারলে false
Future<bool> openExternal(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// শেয়ার মাধ্যম: fb | messenger | whatsapp | x | linkedin | copy
Future<void> shareTo(BuildContext context, String where, String title, String link) async {
  final u = Uri.encodeComponent(link);
  final t = Uri.encodeComponent(title);
  bool ok = false;
  switch (where) {
    case 'fb':
      ok = await openExternal('https://www.facebook.com/sharer/sharer.php?u=$u');
      break;
    case 'messenger':
      ok = await openExternal('fb-messenger://share/?link=$u');
      if (!ok) ok = await openExternal('https://www.facebook.com/sharer/sharer.php?u=$u');
      break;
    case 'whatsapp':
      ok = await openExternal('https://wa.me/?text=$t%20$u');
      break;
    case 'x':
      ok = await openExternal('https://twitter.com/intent/tweet?text=$t&url=$u');
      break;
    case 'linkedin':
      ok = await openExternal('https://www.linkedin.com/sharing/share-offsite/?url=$u');
      break;
    case 'copy':
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('লিংক কপি হয়েছে'), duration: Duration(seconds: 2)));
      }
      return;
  }
  if (!ok) await Share.share('$title\n$link');
}

/// ইউটিউব লিংক বা আইডি থেকে ১১ অক্ষরের ভিডিও আইডি বের করে
String youtubeId(String s) {
  final v = s.trim();
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v)) return v;
  final m = RegExp(r'(?:v=|youtu\.be/|embed/|shorts/|live/)([A-Za-z0-9_-]{11})').firstMatch(v);
  return m?.group(1) ?? '';
}
