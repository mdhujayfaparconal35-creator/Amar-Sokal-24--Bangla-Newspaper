import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../widgets.dart';

class CategoryScreen extends StatelessWidget {
  final Category category;
  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: PagedList<NewsItem>(
        pageSize: 15,
        fetch: (p) => Api.posts(category: category.id, page: p),
        itemBuilder: (_, n) => NewsCard(n),
      ),
    );
  }
}
