import 'cards_api.dart';

/// ফটো কার্ডের ডেমো কমেন্ট (নিউজ অ্যাপে যেমন পাঠকের কমেন্ট থাকে)।
/// প্রতিটি কার্ডের নিজস্ব স্থির সংখ্যা ও স্থির কমেন্ট — আইডি থেকে হিসাব, প্রতিবার একই।
/// সব কমেন্টই সাধারণ ধরনের, কোনো দল/ব্যক্তি/ঘটনার নাম নেই।
/// বন্ধ করতে: নিচের [enabled] কে false করুন।
class FakeComments {
  static const bool enabled = true;

  static const _names = [
    'রফিকুল ইসলাম', 'মিনারা বেগম', 'সুমন আহমেদ', 'তানভীর হাসান', 'নুসরাত জাহান', 'মাহমুদুল হাসান',
    'শারমিন আক্তার', 'জাহিদ হোসেন', 'ফারজানা ইয়াসমিন', 'আরিফ মিয়া', 'রুবেল শেখ', 'সাদিয়া ইসলাম',
    'কামরুল হাসান', 'তাসলিমা খাতুন', 'ইমরান হোসেন', 'মামুন অর রশীদ', 'নাজমুল হুদা', 'শাহিনুর আলম',
    'রিমা আক্তার', 'জসিম উদ্দিন', 'মোস্তাফিজুর রহমান', 'লিটন দাস', 'সুমাইয়া খানম', 'হাবিবুর রহমান',
  ];

  static const _texts = [
    'ধন্যবাদ, খবরটা জানানোর জন্য।',
    'সঠিক সময়ে সঠিক খবর, ধন্যবাদ আমার সকাল ২৪।',
    'আল্লাহ সবাইকে হেফাজত করুন।',
    'খুবই গুরুত্বপূর্ণ তথ্য, জানিয়ে দিলেন বলে ধন্যবাদ।',
    'প্রশাসনের এ বিষয়ে নজর দেওয়া উচিত।',
    'এমন খবর আরও চাই, ভালো লাগলো।',
    'শেয়ার করে দিলাম, সবার জানা দরকার।',
    'আমার সকাল ২৪-এর জন্য শুভকামনা রইল।',
    'দ্রুত সমাধান হোক, এটাই চাওয়া।',
    'সবাই সচেতন হলে ভালো হতো।',
    'তথ্যের জন্য ধন্যবাদ ভাই।',
    'অনেকদিন পর একটা কাজের খবর পেলাম।',
    'আরও বিস্তারিত দিলে ভালো হতো ভাই।',
    'এই খবরটা অনেকেই জানে না, শেয়ার করা দরকার।',
    'ঠিক বলেছেন, আমিও একমত।',
    'আপনাদের নিউজ আমি নিয়মিত পড়ি।',
    'সত্যি কথা বলতে এটা আমাদের সবার বিষয়।',
    'ভালো উদ্যোগ, এগিয়ে যান।',
    'এলাকার মানুষ এতে উপকৃত হবে আশা করি।',
    'খবরটা ছড়িয়ে দিন, সবাই জানুক।',
    'ধন্যবাদ আমার সকাল ২৪ পরিবারকে।',
    'এ নিয়ে আরও খোঁজ নিয়ে জানালে ভালো হয়।',
    'দোয়া রইল সবার জন্য।',
    'কথাগুলো একদম ঠিক, ধন্যবাদ।',
  ];

  static int _hs(String s) {
    var x = 0x811c9dc5;
    for (final c in s.codeUnits) {
      x = ((x ^ c) * 0x01000193) & 0x7fffffff;
    }
    x = ((x ^ (x >> 15)) * 2246822519) & 0x7fffffff;
    return x ^ (x >> 13);
  }

  /// কার্ডে কয়টা ডেমো কমেন্ট: বেশিরভাগ ২-৭, কিছু ৮-১৪, কিছু ১৫-২২
  static int baseCount(String cardId) {
    if (!enabled) return 0;
    final n = _hs('cc$cardId');
    final t = n % 20;
    if (t < 12) return 2 + (n ~/ 20) % 6;
    if (t < 18) return 8 + (n ~/ 20) % 7;
    return 15 + (n ~/ 20) % 8;
  }

  static const _strides = [5, 7, 11, 13, 17, 19, 23]; // ২৪ এর সাথে মৌলিক => একই কার্ডে নাম/কমেন্ট দুবার আসে না

  /// নতুন কমেন্ট আগে (আসল কমেন্টের মতোই)
  static List<CardComment> forCard(PhotoCard card) {
    final n = baseCount(card.id);
    if (n == 0) return const [];
    final h = _hs('cs${card.id}');
    final nameStride = _strides[h % _strides.length];
    final textStride = _strides[(h ~/ 7) % _strides.length];
    final nameStart = (h ~/ 49) % _names.length;
    final textStart = (h ~/ 343) % _texts.length;
    final now = DateTime.now().toUtc();
    var t = DateTime.tryParse(card.created)?.toUtc() ?? now.subtract(const Duration(hours: 6));
    final limit = now.subtract(const Duration(minutes: 1));
    final out = <CardComment>[];
    for (var i = 0; i < n; i++) {
      t = t.add(Duration(minutes: 2 + _hs('${card.id}t$i') % (50 + i * 35)));
      final at = t.isAfter(limit) ? limit.subtract(Duration(minutes: (n - i) * 2)) : t;
      out.add(CardComment(
        id: -(i + 1),
        name: _names[(nameStart + i * nameStride) % _names.length],
        text: _texts[(textStart + i * textStride) % _texts.length],
        created: at.toIso8601String(),
        mine: false,
      ));
    }
    return out.reversed.toList();
  }
}
