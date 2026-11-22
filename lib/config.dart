import 'package:flutter/material.dart';

/// অ্যাপের মূল সেটিংস। ডিজাইন/রঙ/মেনু ইত্যাদি এখানে নয়, ওয়েবসাইটের অ্যাডমিন প্যানেল থেকে বদলান।
/// এখানকার মানগুলো শুধু প্রথমবার, ইন্টারনেট না থাকলে ব্যবহার হয় (ডিফল্ট)।
class AppConfig {
  static const String appName = 'আমার সকাল ২৪';
  static const String apiBase = 'https://amarsokal24.com/wp-json/as-app/v1';
  /// ফুটারে দেখানো নাম (ফাঁকা রাখলে ওই লাইন দেখাবে না)
  static const String editorPublisher = 'বাদল সিকদার';
  static const String epaperUrl = 'https://epaper.amarsokal24.com/';
  static const String siteName = 'আমার সকাল ২৪';

  static const Color brand = Color(0xFF000B3F);

  /// অ্যাডমিন প্যানেলের "সিস্টেম" ট্যাবে "Key বাধ্যতামূলক" চালু করলে সেখানকার API Key এখানে বসান।
  /// ফাঁকা রাখলে কোনো Key পাঠানো হয় না (Key বাধ্যতামূলক না থাকলে এটাই ঠিক)।
  static const String apiKey = '';

  /// এই APK-র Build নম্বর (pubspec.yaml এর version এর + এর পরের সংখ্যা, যেমন 1.1.0+2 => 2)।
  /// নতুন Native ফিচার সহ APK বের করলে দুটোই একসাথে বাড়ান; অ্যাডমিনে "ন্যূনতম Build নম্বর" দিলে
  /// তার চেয়ে পুরনো অ্যাপে আপডেটের বার্তা আসবে।
  static const int build = 12;

  /// কনফিগ কত মিনিট পর পর নতুন আছে কিনা দেখবে (অ্যাপ খোলা অবস্থায়)।
  static const int configRefreshMinutes = 5;
}
