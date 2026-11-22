import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'screens/post_screen.dart';
import 'screens/video_player_screen.dart';

/// পুরো অ্যাপের একটি Navigator চাবি
final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

/// লাইট ভার্সন: ফোনের নোটিফিকেশন প্যাকেজ ছাড়া (বিল্ড সহজ রাখতে)। সুইচ কাজ করে, পরে পুরো ভার্সন যোগ হবে।
class Notifier {
  static Future<void> start() async {}
  static Future<void> checkNew() async {}
  static Future<void> handleLaunch() async {}

  static Future<bool> isOn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('notif_on') ?? true;
  }

  static Future<void> setOn(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_on', v);
  }

  static Future<void> handlePayload(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    final nav = appNavKey.currentState;
    if (nav == null) return;
    try {
      final m = Map<String, dynamic>.from(jsonDecode(payload));
      final id = (m['id'] as num).toInt();
      if (m['t'] == 'video') {
        final v = VideoItem(id: id, title: '${m['title'] ?? ''}', date: '${m['date'] ?? ''}', youtube: '${m['youtube'] ?? ''}', thumb: '${m['thumb'] ?? ''}');
        nav.push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: v)));
      } else {
        nav.push(MaterialPageRoute(builder: (_) => PostScreen(id: id)));
      }
    } catch (_) {}
  }
}
