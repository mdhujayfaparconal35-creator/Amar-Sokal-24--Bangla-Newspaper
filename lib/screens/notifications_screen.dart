import 'package:flutter/material.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../models.dart';

/// নোটিফিকেশন ট্যাব: অ্যাডমিনের ব্রেকিং নিউজ লেখাগুলো তালিকায় দেখায়।
class NotificationsScreen extends StatelessWidget {
  final bool inShell;
  const NotificationsScreen({super.key, this.inShell = false});

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: inShell,
      title: const Text('নোটিফিকেশন'),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: ConfigStore.notifier,
        builder: (context, s, _) {
          final list = s.breaking.items;
          if (list.isEmpty) {
            return const Center(child: Text('কোনো নোটিফিকেশন নেই'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.notifications_none),
              title: Text(list[i]),
            ),
          );
        },
      ),
    );
  }
}
