import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'config.dart';
import 'notifications.dart';

/// ব্যাকগ্রাউন্ডে (অ্যাপ বন্ধ থাকলেও) প্রতি ~১৫ মিনিটে নতুন নিউজ/ভিডিও দেখে
@pragma('vm:entry-point')
void notifCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      await Notifier.checkNew();
    } catch (_) {}
    return true;
  });
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
      await Workmanager().initialize(notifCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        'as_check_new',
        'as_check_new',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
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
