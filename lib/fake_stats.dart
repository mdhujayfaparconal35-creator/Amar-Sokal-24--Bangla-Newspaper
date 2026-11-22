import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'util.dart';

/// ডেমো ভিউ ও শেয়ার সংখ্যা।
/// প্রতিটি নিউজের নিজস্ব স্থির সংখ্যা (নিউজ আইডি থেকে হিসাব, গোল সংখ্যা নয়, যেমন ৪৩৭ / ৯১১ / ৩৪১২)।
/// নিউজ পড়লে বা রিফ্রেশ করলে প্রতিবার ভিউ ৭ করে বাড়ে (শেয়ার ২ করে)।
class FakeStats {
  static Map<String, int> _opens = {};
  static const _k = 'fake_opens';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_k);
      if (s != null) {
        _opens = (jsonDecode(s) as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
      }
    } catch (_) {}
  }

  static int _h(int id, int salt) {
    var x = ((id * 73856093) ^ (salt * 19349663)) & 0x7fffffff;
    x = ((x ^ (x >> 15)) * 2246822519) & 0x7fffffff;
    x = ((x ^ (x >> 13)) * 3266489917) & 0x7fffffff;
    return x ^ (x >> 16);
  }

  static int _opensOf(int id) => _opens['$id'] ?? 0;

  /// ভিউ: বেশিরভাগ ৪০০-৯২০, কিছু ৯০০-১৯০০, কিছু ২০০০-৪৪০০
  static int views(int id) {
    final t = _h(id, 1) % 20;
    int base;
    if (t < 13) {
      base = 400 + _h(id, 2) % 520;
    } else if (t < 18) {
      base = 900 + _h(id, 3) % 1000;
    } else {
      base = 2000 + _h(id, 4) % 2400;
    }
    if (base % 10 == 0) base += 1 + _h(id, 5) % 9;
    return base + 7 * _opensOf(id);
  }

  /// শেয়ার: বেশিরভাগ ৭০-১৬৯, কিছু ১৭০-৩৪৯, কিছু ৩৫০-৭৯৯
  static int shares(int id) {
    final t = _h(id, 11) % 20;
    int base;
    if (t < 13) {
      base = 70 + _h(id, 12) % 100;
    } else if (t < 18) {
      base = 170 + _h(id, 13) % 180;
    } else {
      base = 350 + _h(id, 14) % 450;
    }
    if (base % 10 == 0) base += 1 + _h(id, 15) % 9;
    return base + 2 * _opensOf(id);
  }

  static void bump(int id) => bumpMany([id]);

  static void bumpMany(Iterable<int> ids) {
    for (final id in ids) {
      _opens['$id'] = _opensOf(id) + 1;
    }
    if (_opens.length > 600) {
      final drop = _opens.keys.take(_opens.length - 600).toList();
      for (final k in drop) {
        _opens.remove(k);
      }
    }
    _save();
  }

  static Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k, jsonEncode(_opens));
    } catch (_) {}
  }

  /// বাংলা অঙ্কে, হাজারের কমা সহ (১,২৩৪)
  static String fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return bn(b.toString());
  }
}
