import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'util.dart';

/// ডেমো ভিউ ও শেয়ার সংখ্যা।
/// প্রতিটি নিউজের নিজস্ব স্থির সংখ্যা (নিউজ আইডি থেকে হিসাব, গোল সংখ্যা নয়, যেমন ৪৩৭ / ৯১১ / ৩৪১২)।
/// নিউজ পড়লে বা রিফ্রেশ করলে প্রতিবার ভিউ ৭ করে বাড়ে (শেয়ার ২ করে)।
class FakeStats {
  static Map<String, int> _opens = {};
  static const _k = 'fake_opens';

  // ভিডিও ও রিলসের জন্য আলাদা হিসাব (আইডি ফেসবুকের লম্বা টেক্সট আইডি)
  static Map<String, int> _mOpens = {};
  static const _mk = 'fake_media_opens';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_k);
      if (s != null) {
        _opens = (jsonDecode(s) as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
      }
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_mk);
      if (s != null) {
        _mOpens = (jsonDecode(s) as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
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

  /// টেক্সট আইডি থেকে স্থির সংখ্যা (FNV-1a) — প্রতিবার অ্যাপ খুললে একই আসে
  static int _hs(String s) {
    var x = 0x811c9dc5;
    for (final c in s.codeUnits) {
      x = ((x ^ c) * 0x01000193) & 0x7fffffff;
    }
    return x;
  }

  /// ভিডিও/রিলস ভিউ: প্রায় ৬৫% ৬০০-১,৯৮০, ২৫% ২,০০০-৫,৯০০, আর ১০% ৬৮,০০০-৯৪,৯৯৯ (৮০ হাজারের আশেপাশে, গোল নয়)
  /// প্রতিবার দেখলে ৭ করে বাড়ে।
  static int mediaViews(String id) {
    final n = _hs(id);
    final t = _h(n, 21) % 20;
    int base;
    if (t < 13) {
      base = 600 + _h(n, 22) % 1380;
    } else if (t < 18) {
      base = 2000 + _h(n, 23) % 3900;
    } else {
      base = 68000 + _h(n, 24) % 27000;
    }
    if (base % 10 == 0) base += 1 + _h(n, 25) % 9;
    return base + 7 * (_mOpens[id] ?? 0);
  }

  /// রিলসের লাইক: ভিউয়ের ভিত্তি সংখ্যার প্রায় ৪-১১% (গোল নয়), সর্বনিম্ন ১৩।
  /// প্রতিটি রিলসের নিজস্ব স্থির সংখ্যা; ব্যবহারকারী লাইক দিলে ১ বাড়ে (অ্যাপ থেকে যোগ হয়)।
  static int mediaLikes(String id) {
    final n = _hs(id);
    final t = _h(n, 21) % 20;
    int base;
    if (t < 13) {
      base = 600 + _h(n, 22) % 1380;
    } else if (t < 18) {
      base = 2000 + _h(n, 23) % 3900;
    } else {
      base = 68000 + _h(n, 24) % 27000;
    }
    final pct = 4 + _h(n, 41) % 8; // ৪-১১%
    var likes = base * pct ~/ 100 + _h(n, 42) % 17;
    if (likes < 13) likes = 13 + _h(n, 43) % 20;
    if (likes % 10 == 0) likes += 1 + _h(n, 44) % 9;
    return likes;
  }

  /// ফটো কার্ডের লাইকের ভিত্তি (আসল লাইকের সাথে যোগ হয়): সর্বনিম্ন ১৩।
  /// ৬০% ১৩-১৪৯, ২৫% ১৫০-৬৯৯, ১০% ৭০০-১,৭৯৯, ৫% ১,৮০০-৩,১০০
  static int cardLikes(String id) {
    final n = _hs('card$id');
    final t = _h(n, 31) % 20;
    int base;
    if (t < 12) {
      base = 13 + _h(n, 32) % 137;
    } else if (t < 17) {
      base = 150 + _h(n, 33) % 550;
    } else if (t < 19) {
      base = 700 + _h(n, 34) % 1100;
    } else {
      base = 1800 + _h(n, 35) % 1301;
    }
    return base;
  }

  static void bumpMedia(String id) {
    if (id.isEmpty) return;
    _mOpens[id] = (_mOpens[id] ?? 0) + 1;
    if (_mOpens.length > 600) {
      final drop = _mOpens.keys.take(_mOpens.length - 600).toList();
      for (final k in drop) {
        _mOpens.remove(k);
      }
    }
    _saveMedia();
  }

  static Future<void> _saveMedia() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_mk, jsonEncode(_mOpens));
    } catch (_) {}
  }

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
