import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'api.dart';
import 'config.dart';
import 'models.dart';
import 'screens/post_screen.dart';
import 'screens/video_player_screen.dart';

/// পুরো অ্যাপের একটি Navigator চাবি: নোটিফিকেশনে ট্যাপ করলে যেকোনো জায়গা থেকে নিউজ/ভিডিও খুলতে লাগে।
final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

/// ব্যাকগ্রাউন্ডে (অ্যাপ বন্ধ থাকলেও) প্রতি ~১৫ মিনিটে নতুন নিউজ/ভিডিও আছে কিনা দেখে।
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

/// নতুন নিউজ ও নতুন ভিডিওর নোটিফিকেশন।
/// নিয়ম: প্রথমবার শুধু "এখন যা আছে" মনে রাখে (পুরনো খবরের নোটিফিকেশন আসে না);
/// এরপর নতুন যা আসে তার জন্য একটি করে নোটিফিকেশন (সর্বোচ্চ ৩টি করে)।
class Notifier {
  static final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static String? _pending;
  static bool _checking = false;

  static const _kOn = 'notif_on';
  static const _kPosts = 'notif_seen_posts';
  static const _kVideos = 'notif_seen_videos';

  static Future<void> _init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@drawable/ic_stat');
    await _fln.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (r) => handlePayload(r.payload),
    );
    _ready = true;
  }

  /// অ্যাপ চালুর সময়: প্লাগইন চালু, অনুমতি চাওয়া, ব্যাকগ্রাউন্ড কাজ নিবন্ধন
  static Future<void> start() async {
    try {
      await _init();
      final android = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await Workmanager().initialize(notifCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        'as_check_new',
        'as_check_new',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {
      // নোটিফিকেশন চালু না হলেও অ্যাপ স্বাভাবিক চলবে
    }
  }

  static Future<bool> isOn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kOn) ?? true;
  }

  static Future<void> setOn(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOn, v);
    if (v) {
      try {
        await _init();
        await _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      } catch (_) {}
    }
  }

  /// নতুন নিউজ/ভিডিও দেখে নোটিফিকেশন দেয় (ফোরগ্রাউন্ড ও ব্যাকগ্রাউন্ড দুই জায়গা থেকেই চলে)
  static Future<void> checkNew() async {
    if (_checking) return;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_kOn) ?? true)) return;
      await _init();

      try {
        final posts = await Api.posts(perPage: 8);
        final seen = prefs.getStringList(_kPosts);
        if (seen != null) {
          final fresh = posts.where((p) => !seen.contains('${p.id}')).take(3).toList().reversed;
          for (final p in fresh) {
            await _show(
              id: p.id,
              video: false,
              title: p.title,
              body: p.category?.name.isNotEmpty == true ? 'নতুন খবর • ${p.category!.name}' : 'নতুন খবর',
              image: p.image,
              payload: {'t': 'post', 'id': p.id},
            );
          }
        }
        final all = {...posts.map((e) => '${e.id}'), ...?seen}.take(60).toList();
        await prefs.setStringList(_kPosts, all);
      } catch (_) {}

      try {
        final vids = await Api.videos(page: 1);
        final seen = prefs.getStringList(_kVideos);
        if (seen != null) {
          final fresh = vids.where((v) => !seen.contains('${v.id}')).take(3).toList().reversed;
          for (final v in fresh) {
            await _show(
              id: v.id,
              video: true,
              title: v.title,
              body: 'নতুন ভিডিও',
              image: v.thumb,
              payload: {'t': 'video', 'id': v.id, 'title': v.title, 'date': v.date, 'youtube': v.youtube, 'thumb': v.thumb},
            );
          }
        }
        final all = {...vids.map((e) => '${e.id}'), ...?seen}.take(60).toList();
        await prefs.setStringList(_kVideos, all);
      } catch (_) {}
    } finally {
      _checking = false;
    }
  }

  static Future<void> _show({
    required int id,
    required bool video,
    required String title,
    required String body,
    required String image,
    required Map<String, dynamic> payload,
  }) async {
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
          ? BigPictureStyleInformation(
              pic,
              contentTitle: title,
              summaryText: body,
              hideExpandedLargeIcon: true,
            )
          : BigTextStyleInformation(title, contentTitle: body),
    );
    final nid = (video ? 1000000000 : 0) + (id % 900000000);
    await _fln.show(nid, pic != null ? body : title, pic != null ? title : body, NotificationDetails(android: details), payload: jsonEncode(payload));
  }

  /// নোটিফিকেশনে ট্যাপ: নিউজ বা ভিডিও অ্যাপের ভেতরেই খোলে
  static Future<void> handlePayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    final nav = appNavKey.currentState;
    if (nav == null) {
      _pending = payload;
      return;
    }
    try {
      final m = Map<String, dynamic>.from(jsonDecode(payload));
      final id = (m['id'] as num).toInt();
      if (m['t'] == 'video') {
        final v = VideoItem(
          id: id,
          title: '${m['title'] ?? ''}',
          date: '${m['date'] ?? ''}',
          youtube: '${m['youtube'] ?? ''}',
          thumb: '${m['thumb'] ?? ''}',
        );
        nav.push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: v)));
      } else {
        nav.push(MaterialPageRoute(builder: (_) => PostScreen(id: id)));
      }
    } catch (_) {}
  }

  /// অ্যাপ বন্ধ থাকা অবস্থায় নোটিফিকেশনে ট্যাপ করে খুললে, হোম আঁকা হওয়ার পর সেটি খোলে
  static Future<void> handleLaunch() async {
    try {
      await _init();
      final d = await _fln.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) {
        await handlePayload(d!.notificationResponse?.payload);
      } else if (_pending != null) {
        final p = _pending;
        _pending = null;
        await handlePayload(p);
      }
    } catch (_) {}
  }
}
