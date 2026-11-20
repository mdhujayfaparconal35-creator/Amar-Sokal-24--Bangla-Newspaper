import 'package:flutter/material.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../widgets.dart';

class SearchScreen extends StatefulWidget {
  final bool inShell;
  const SearchScreen({super.key, this.inShell = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final q = v.trim();
    if (q.length < 2) return;
    FocusScope.of(context).unfocus();
    setState(() => _query = q);
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: widget.inShell,
      keepTitle: true,
      headerSearch: false,
      title: TextField(
        controller: _ctrl,
        textInputAction: TextInputAction.search,
        onSubmitted: _submit,
        decoration: const InputDecoration(hintText: 'খবর খুঁজুন (শিরোনামে)', border: InputBorder.none),
      ),
      actions: [IconButton(icon: const Icon(Icons.search), onPressed: () => _submit(_ctrl.text))],
      body: _query.isEmpty
          ? const Center(child: Text('খুঁজতে কমপক্ষে ২ অক্ষর লিখুন'))
          : PagedList<NewsItem>(
              key: ValueKey(_query),
              pageSize: 15,
              fetch: (p) => Api.posts(search: _query, page: p),
              itemBuilder: (_, n) => NewsCard(n),
            ),
    );
  }
}
