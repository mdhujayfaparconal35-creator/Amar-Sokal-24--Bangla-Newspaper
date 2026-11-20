import 'package:flutter/material.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../widgets.dart';

class CategoryScreen extends StatelessWidget {
  final Category category;
  final bool inShell;
  const CategoryScreen({super.key, required this.category, this.inShell = false});

  Widget _list() {
    final list = PagedList<NewsItem>(
      key: ValueKey('cat${category.id}'),
      pageSize: 15,
      fetch: (p) => Api.posts(category: category.id, page: p),
      itemBuilder: (_, n) => NewsCard(n),
    );
    // ভেতরে ঢুকলে (ট্যাব নয়) হেডারে লোগো থাকে, তাই ক্যাটাগরির নাম তালিকার ওপরে দেখানো হয়
    if (inShell) return list;
    return Column(children: [
      Align(alignment: Alignment.centerLeft, child: SectionTitle(category.name)),
      Expanded(child: list),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: inShell,
      title: Text(category.name),
      body: _list(),
    );
  }
}
