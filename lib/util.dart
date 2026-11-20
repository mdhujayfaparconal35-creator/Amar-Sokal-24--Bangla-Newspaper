import 'package:url_launcher/url_launcher.dart';

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
  await launchUrl(Uri.parse('https://www.youtube.com/watch?v=$id'), mode: LaunchMode.externalApplication);
}

/// লিংক খোলে (ব্রাউজারে)। ভুল/https নয় এমন লিংক উপেক্ষা করে।
Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' && uri.scheme != 'http') return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok) await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
