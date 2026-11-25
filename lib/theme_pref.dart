import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// পাঠকের নিজের থিম পছন্দ: null = অ্যাডমিনের ঠিক-করা মোড, নইলে system / light / dark
class ThemePref {
  static final ValueNotifier<String?> mode = ValueNotifier<String?>(null);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final m = p.getString('user_theme');
      mode.value = const ['system', 'light', 'dark'].contains(m) ? m : null;
    } catch (_) {}
  }

  static Future<void> set(String m) async {
    mode.value = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('user_theme', m);
    } catch (_) {}
  }
}
