import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'config.dart';
import 'notifications.dart';
import 'rep/rep_api.dart';

/// ব্যাকগ্রাউন্ডে (অ্যাপ বন্ধ থাকলেও) প্রতি ~১৫ মিনিটে নতুন নিউজ/ভিডিও দেখে
@pragma('vm:entry-point')
Future<void> notifAlarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await Notifier.checkNew();
    await RepApi.pollAndShow(); // প্রতিনিধির নিউজ প্রকাশ/বাতিলের নোটিফিকেশন
  } catch (_) {}
}

/// ফোনের নোটিফিকেশন বারে নোটিফিকেশন দেখানো (flutter_local_notifications)
class SysNotify {
  static final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@drawable/ic_stat');
    await _fln.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (r) => Notifier.handlePayload(r.payload),
    );
    _ready = true;
  }

  static Future<void> requestPermission() async {
    try {
      await init();
      await _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> start() async {
    try {
      await requestPermission();
      await AndroidAlarmManager.initialize();
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        7001,
        notifAlarmCallback,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
  }

  static Future<void> show({
    required int id,
    required bool video,
    required String title,
    required String body,
    required String image,
    required String payload,
  }) async {
    try {
      await init();
      ByteArrayAndroidBitmap? pic;
      if (image.startsWith('http')) {
        try {
          final r = await http.get(Uri.parse(image)).timeout(const Duration(seconds: 12));
          if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) pic = ByteArrayAndroidBitmap(r.bodyBytes);
        } catch (_) {}
      }
      final details = AndroidNotificationDetails(
        video ? 'as_videos' : 'as_news',
        video ? 'নতুন ভিডিও' : 'নতুন খবর',
        channelDescription: video ? 'নতুন ভিডিও আপলোড হলে' : 'নতুন খবর প্রকাশ হলে',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat',
        color: AppConfig.brand,
        largeIcon: pic,
        styleInformation: pic != null
            ? BigPictureStyleInformation(pic, contentTitle: title, summaryText: body, hideExpandedLargeIcon: true)
            : BigTextStyleInformation(title, contentTitle: body),
      );
      final nid = (video ? 1000000000 : 0) + (id % 900000000);
      await _fln.show(nid, pic != null ? body : title, pic != null ? title : body, NotificationDetails(android: details), payload: payload);
    } catch (_) {}
  }

  /// প্রতিনিধির নিউজ প্রকাশিত/বাতিল হলে
  static Future<void> showRep({required int id, required String title, required String body, required String payload}) async {
    try {
      await init();
      final details = AndroidNotificationDetails(
        'as_rep',
        'প্রতিনিধির নিউজ',
        channelDescription: 'আপনার পাঠানো নিউজ প্রকাশ হলে বা না হলে',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat',
        color: AppConfig.brand,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
      );
      await _fln.show(1900000000 + (id % 90000000), title, body, NotificationDetails(android: details), payload: payload);
    } catch (_) {}
  }

  /// অ্যাপ বন্ধ অবস্থায় নোটিফিকেশনে ট্যাপ করে খুললে তার payload
  static Future<String?> launchPayload() async {
    try {
      await init();
      final d = await _fln.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) return d!.notificationResponse?.payload;
    } catch (_) {}
    return null;
  }
}
