import 'package:flutter/material.dart';

/// অ্যাপের মূল সেটিংস। ডিজাইন/রঙ/মেনু ইত্যাদি এখানে নয়, ওয়েবসাইটের অ্যাডমিন প্যানেল থেকে বদলান।
/// এখানকার মানগুলো শুধু প্রথমবার, ইন্টারনেট না থাকলে ব্যবহার হয় (ডিফল্ট)।
class AppConfig {
  static const String appName = 'আমার সকাল ২৪';
  static const String apiBase = 'https://amarsokal24.com/wp-json/as-app/v1';
  /// ফুটারে দেখানো নাম (ফাঁকা রাখলে ওই লাইন দেখাবে না)
  static const String editorPublisher = 'বাদল সিকদার';
  /// প্রতিনিধি অ্যাপের সার্ভার (T2) ও ফেসবুক রিলসের ঠিকানা
  static const String t2Base = 'https://t2.astechnologiesltd.com';
  static const String reelsUrl = 'https://www.facebook.com/amarsokal24news/reels/';
  static const String epaperUrl = 'https://epaper.amarsokal24.com/';
  static const String siteName = 'আমার সকাল ২৪';

  static const Color brand = Color(0xFF000B3F);

  /// অ্যাডমিন প্যানেলের "সিস্টেম" ট্যাবে "Key বাধ্যতামূলক" চালু করলে সেখানকার API Key এখানে বসান।
  /// ফাঁকা রাখলে কোনো Key পাঠানো হয় না (Key বাধ্যতামূলক না থাকলে এটাই ঠিক)।
  static const String apiKey = '';

  /// এই APK-র Build নম্বর (pubspec.yaml এর version এর + এর পরের সংখ্যা, যেমন 1.1.0+2 => 2)।
  /// নতুন Native ফিচার সহ APK বের করলে দুটোই একসাথে বাড়ান; অ্যাডমিনে "ন্যূনতম Build নম্বর" দিলে
  /// তার চেয়ে পুরনো অ্যাপে আপডেটের বার্তা আসবে।
  static const int build = 23;

  /// কনফিগ কত মিনিট পর পর নতুন আছে কিনা দেখবে (অ্যাপ খোলা অবস্থায়)।
  static const int configRefreshMinutes = 5;

  /// হোমের ওপরের চিপ ও নিচের ক্যাটাগরি-সেকশনে শুধু এই (মূল) ক্যাটাগরিগুলো দেখায়, এই ক্রমে।
  /// নাম সাইটের ক্যাটাগরির নামের সাথে হুবহু মিলতে হবে। বদলাতে চাইলে শুধু এই তালিকা বদলান।
  static const List<String> mainCategories = [
    'রাজনীতি', 'অর্থনীতি', 'আন্তর্জাতিক', 'খেলা', 'বিনোদন', 'শিক্ষা', 'স্বাস্থ্য', 'বিজ্ঞান ও প্রযুক্তি', 'মতামত', 'ধর্ম', 'জাতীয়',
  ];

  /// মূল তালিকার সাথে কোনো নাম না মিললে (বা ৩টির কম মিললে) বেশি খবরওয়ালা ক্যাটাগরি দেখানো হয়;
  /// তখনও এই গুরুত্বহীন/এলাকাভিত্তিক ক্যাটাগরিগুলো বাদ থাকে।
  static const List<String> hiddenCategories = [
    'বাংলাদেশ', 'ভারত', 'পাকিস্তান', 'ময়মনসিংহ', 'ময়মনশিং', 'ঢাকা', 'চট্টগ্রাম', 'রাজশাহী', 'খুলনা', 'বরিশাল', 'সিলেট', 'রংপুর',
    'শোকাহত', 'আবহাওয়া', 'নির্বাচিত', 'অন্যান্য',
  ];

  /// সাইড মেনুতে শুধু এই দরকারি ক্যাটাগরিগুলো (সাইটের ক্যাটাগরির নামের সাথে হুবহু মিলতে হবে; না মিললে বাদ যায়)
  static const List<String> drawerCategories = ['সারাদেশ', 'রাজনীতি', 'আন্তর্জাতিক', 'খেলাধুলা', 'বিনোদন', 'অপরাধ'];

  /// সাইড মেনুর অ্যাপ ডাউনলোড বাটনের লিংক (পাবলিশ হলে আসল লিংক বসান)
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.amarsokal24.amarsokal24_app';
  static const String appStoreUrl = 'https://amarsokal24.com/';
  static const String englishUrl = 'https://en.amarsokal24.com/';
  static const String shopUrl = 'https://shop.amarsokal24.com/';

  /// হোমের ভিডিও সেকশনে কয়টি ফেসবুক ভিডিও
  static const int homeVideoCount = 8;

  /// হোমের নিচে কয়টি ক্যাটাগরি-সেকশন, প্রতিটিতে কয়টি খবর
  static const int homeCategoryBlocks = 6;
  static const int homeCategoryCount = 4;
}
