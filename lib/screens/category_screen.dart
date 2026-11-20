import 'package:flutter/material.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../widgets.dart';

class CategoryScreen extends StatelessWidget {
  final Category category;
  final bool inShell;
  const CategoryScreen({super.key, required this.category, this.inShell = false});

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: inShell,
      title: Text(category.name),
      body: PagedList<NewsItem>(
        key: ValueKey('cat${category.id}'),
        pageSize: 15,
        fetch: (p) => Api.posts(category: category.id, page: p),
        itemBuilder: (_, n) => NewsCard(n),
      ),
    );
  }
}
