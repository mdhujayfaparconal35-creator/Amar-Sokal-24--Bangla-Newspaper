import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'widgets.dart';

/// "সংরক্ষিত খবর": ফোনেই জমা থাকে (পরে নেট ছাড়াই তালিকা দেখা যায়, খুললে নিউজ আবার লোড হয়)
class SavedStore {
  static const _k = 'saved_news';
  static final ValueNotifier<List<NewsItem>> items = ValueNotifier<List<NewsItem>>([]);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getStringList(_k) ?? const <String>[];
      items.value = raw.map((e) => NewsItem.fromJson(Map<String, dynamic>.from(jsonDecode(e) as Map))).toList();
    } catch (_) {}
  }

  static bool has(int id) => items.value.any((e) => e.id == id);

  static Map<String, dynamic> _j(NewsItem n) => {
        'id': n.id,
        'title': n.title,
        'excerpt': n.excerpt,
        'image': n.image,
        'date': n.date,
        'link': n.link,
        'reporter': n.reporter,
        if (n.category != null) 'category': {'id': n.category!.id, 'name': n.category!.name, 'slug': n.category!.slug, 'count': n.category!.count},
      };

  /// সংরক্ষণ করলে true, সরালে false
  static Future<bool> toggle(NewsItem n) async {
    final list = [...items.value];
    final i = list.indexWhere((e) => e.id == n.id);
    final added = i < 0;
    if (added) {
      list.insert(0, n);
    } else {
      list.removeAt(i);
    }
    items.value = list.take(200).toList();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_k, items.value.map((e) => jsonEncode(_j(e))).toList());
    } catch (_) {}
    return added;
  }
}

/// খবরের পেজের "সংরক্ষণ করুন" বাটন (আইকনের পাশে পরিষ্কার লেখা)
class SaveButton extends StatelessWidget {
  final NewsItem item;
  const SaveButton({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<List<NewsItem>>(
      valueListenable: SavedStore.items,
      builder: (context, list, _) {
        final saved = list.any((e) => e.id == item.id);
        return TextButton.icon(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: primary),
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, size: 20),
          label: Text(saved ? 'সংরক্ষিত' : 'সংরক্ষণ করুন', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          onPressed: () async {
            HapticFeedback.lightImpact();
            final added = await SavedStore.toggle(item);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(added ? 'খবরটি সংরক্ষিত হয়েছে' : 'সংরক্ষণ থেকে সরানো হয়েছে'), duration: const Duration(seconds: 2)));
          },
        );
      },
    );
  }
}

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সংরক্ষিত খবর')),
      body: ValueListenableBuilder<List<NewsItem>>(
        valueListenable: SavedStore.items,
        builder: (context, list, _) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bookmarks_outlined, size: 64, color: Theme.of(context).disabledColor),
                  const SizedBox(height: 14),
                  const Text('এখনো কোনো খবর সংরক্ষণ করেননি।', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('পছন্দের খবরের পেজে "সংরক্ষণ করুন" চাপুন, এখানে জমা থাকবে।', textAlign: TextAlign.center),
                ]),
              ),
            );
          }
          return ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: [for (final n in list) NewsCard(n)]);
        },
      ),
    );
  }
}
