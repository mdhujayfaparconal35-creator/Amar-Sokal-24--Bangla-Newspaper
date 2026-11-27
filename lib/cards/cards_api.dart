import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../rewards/reward_api.dart';

/// ফেসবুক পেজের একটি ফটো কার্ড (সার্ভার: asr/v1/cards)। লাইক/কমেন্ট অ্যাপের নিজস্ব (ফেসবুকের নয়)।
class PhotoCard {
  final String id, image, caption, created, permalink, pageComment;
  int likes, comments;
  bool liked;
  PhotoCard({
    required this.id,
    required this.image,
    required this.caption,
    required this.created,
    required this.permalink,
    required this.pageComment,
    required this.likes,
    required this.comments,
    required this.liked,
  });

  factory PhotoCard.fromJson(Map<String, dynamic> j) => PhotoCard(
        id: '${j['id'] ?? ''}',
        image: '${j['image'] ?? ''}',
        caption: '${j['caption'] ?? ''}'.trim(),
        created: '${j['created'] ?? ''}',
        permalink: '${j['permalink'] ?? ''}',
        pageComment: '${j['page_comment'] ?? ''}'.trim(),
        likes: ri(j['likes']),
        comments: ri(j['comments']),
        liked: j['liked'] == true,
      );
}

class CardPage {
  final List<PhotoCard> items;
  final String next;
  const CardPage(this.items, this.next);
}

class CardComment {
  final int id;
  final String name, text, created;
  final bool mine;
  const CardComment({required this.id, required this.name, required this.text, required this.created, required this.mine});

  factory CardComment.fromJson(Map<String, dynamic> j) => CardComment(
        id: ri(j['id']),
        name: '${j['name'] ?? ''}',
        text: '${j['text'] ?? ''}',
        created: '${j['created'] ?? ''}',
        mine: j['mine'] == true,
      );
}

class CardsApi {
  static const _ck = 'cards_cache';

  static CardPage _parse(Map<String, dynamic> j) => CardPage(
        ((j['items'] as List?) ?? const []).map((e) => PhotoCard.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        '${j['next'] ?? ''}',
      );

  /// আগেরবারের তালিকা (পেজ খুললেই সাথে সাথে দেখানোর জন্য)
  static Future<CardPage?> cached() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_ck);
      if (raw == null) return null;
      final pg = _parse(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      return pg.items.isEmpty ? null : pg;
    } catch (_) {
      return null;
    }
  }

  static Future<CardPage> list({String after = ''}) async {
    final j = await RewardApi.getJson('/cards?after=${Uri.encodeQueryComponent(after)}');
    if (after.isEmpty) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_ck, jsonEncode(j));
      } catch (_) {}
    }
    return _parse(j);
  }

  /// লাইক/আনলাইক; ফেরত: (liked, মোট লাইক)
  static Future<Map<String, dynamic>> like(String id) => RewardApi.postJson('/cards/like', {'card_id': id});

  static Future<List<CardComment>> comments(String id, int page) async {
    final j = await RewardApi.getJson('/cards/comments?card_id=${Uri.encodeQueryComponent(id)}&page=$page');
    return ((j['items'] as List?) ?? const []).map((e) => CardComment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static Future<Map<String, dynamic>> addComment(String id, String text) => RewardApi.postJson('/cards/comment', {'card_id': id, 'text': text});

  static Future<void> deleteComment(int id) async {
    await RewardApi.postJson('/cards/comment/delete', {'id': '$id'});
  }
}
