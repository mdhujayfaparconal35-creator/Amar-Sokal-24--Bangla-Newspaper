import 'dart:async';
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
  Timer? _deb;

  @override
  void dispose() {
    _deb?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(String v) {
    _deb?.cancel();
    final q = v.trim();
    if (q.length < 2) return;
    FocusScope.of(context).unfocus();
    if (q != _query) setState(() => _query = q);
  }

  void _changed(String v) {
    setState(() {});
    _deb?.cancel();
    final q = v.trim();
    if (q.length < 2) return;
    _deb = Timer(const Duration(milliseconds: 600), () {
      if (mounted && q != _query) setState(() => _query = q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: widget.inShell,
      keepTitle: true,
      headerSearch: false,
      title: TextField(
        controller: _ctrl,
        autofocus: true,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: _submit,
        decoration: const InputDecoration(hintText: 'খবর খুঁজুন (শিরোনামে)', border: InputBorder.none),
      ),
      actions: [
        if (_ctrl.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _deb?.cancel();
              _ctrl.clear();
              setState(() => _query = '');
            },
          ),
        IconButton(icon: const Icon(Icons.search), onPressed: () => _submit(_ctrl.text)),
      ],
      body: _query.isEmpty
          ? const Center(child: Text('খুঁজতে কমপক্ষে ২ অক্ষর লিখুন'))
          : PagedList<NewsItem>(
              adEvery: 5,
              key: ValueKey(_query),
              pageSize: 15,
              fetch: (p) => Api.search(_query, page: p),
              itemBuilder: (_, n) => NewsCard(n),
            ),
    );
  }
}
