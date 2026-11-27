import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ভাষা: ডিফল্ট বাংলা। ওপরের "EN" চাপলে ইংরেজি (ইংরেজি সংস্করণের সাইট + মেনু/ট্যাবের ইংরেজি নাম), "BN" চাপলে আবার বাংলা।
class Lang {
  static final ValueNotifier<bool> en = ValueNotifier<bool>(false);
  static const _k = 'lang_en';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      en.value = p.getBool(_k) ?? false;
    } catch (_) {}
  }

  static Future<void> toggle() async {
    en.value = !en.value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_k, en.value);
    } catch (_) {}
  }

  /// ইংরেজি মোডে পরিচিত বাংলা লেখার ইংরেজি; না মিললে যেমন আছে
  static String t(String bn) => en.value ? (_m[bn.trim()] ?? bn) : bn;

  static const Map<String, String> _m = {
    'হোম': 'Home',
    'ভিডিও': 'Videos',
    'রিলস': 'Reels',
    'নোটিফিকেশন': 'Notifications',
    'ই-পেপার': 'E-Paper',
    'ই-কমার্স': 'E-Commerce',
    'ফটো কার্ড': 'Photo Cards',
    'সর্বশেষ': 'Latest',
    'সার্চ': 'Search',
    'মেনু': 'Menu',
    'ক্যাটাগরি': 'Categories',
    'সারাদেশ': 'Bangladesh',
    'রাজনীতি': 'Politics',
    'অর্থনীতি': 'Economy',
    'আন্তর্জাতিক': 'International',
    'খেলাধুলা': 'Sports',
    'খেলা': 'Sports',
    'বিনোদন': 'Entertainment',
    'অপরাধ': 'Crime',
    'শিক্ষা': 'Education',
    'স্বাস্থ্য': 'Health',
    'বিজ্ঞান ও প্রযুক্তি': 'Science & Tech',
    'মতামত': 'Opinion',
    'ধর্ম': 'Religion',
    'জাতীয়': 'National',
    'থিম': 'Theme',
    'অটো': 'Auto',
    'লাইট': 'Light',
    'ডার্ক': 'Dark',
    'সংরক্ষিত খবর': 'Saved News',
    'প্রতিনিধি প্যানেল': 'Reporter Panel',
    'রিওয়ার্ড কয়েন': 'Reward Coins',
    'খবর পড়ুন, কয়েন জিতুন': 'Read news, earn coins',
    'কয়েন জিতুন': 'Earn Coins',
    'প্রতিনিধি': 'Reporter',
    'মোবাইল অ্যাপস ডাউনলোড করুন': 'Download our mobile app',
    'নোটিফিকেশন (নতুন খবর ও ভিডিও)': 'Notifications',
    'বের হতে আবার ব্যাক চাপুন': 'Press back again to exit',
    'আরও পড়ুন': 'Read more',
    'প্রচ্ছদ': 'Home',
    'পেছনে': 'Back',
  };
}
