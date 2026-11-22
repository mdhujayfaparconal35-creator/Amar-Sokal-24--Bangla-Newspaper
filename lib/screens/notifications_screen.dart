import 'package:flutter/material.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../notifications.dart';

/// নোটিফিকেশন ট্যাব: নতুন খবর/ভিডিওর নোটিফিকেশন চালু-বন্ধের সুইচ + অ্যাডমিনের ব্রেকিং নিউজ।
class NotificationsScreen extends StatefulWidget {
  final bool inShell;
  const NotificationsScreen({super.key, this.inShell = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _on = true;

  @override
  void initState() {
    super.initState();
    Notifier.isOn().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ShellScaffold(
      inShell: widget.inShell,
      title: const Text('নোটিফিকেশন'),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: ConfigStore.notifier,
        builder: (context, s, _) {
          final list = s.breaking.items;
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: [primary, Color.lerp(primary, Colors.black, 0.35)!]),
                boxShadow: [BoxShadow(color: primary.withAlpha(70), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('নতুন খবর ও ভিডিওর নোটিফিকেশন',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
                    SizedBox(height: 2),
                    Text('নতুন নিউজ বা ভিডিও এলেই জানিয়ে দেবে', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ),
                Switch(
                  value: _on,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white30,
                  onChanged: (v) async {
                    setState(() => _on = v);
                    await Notifier.setOn(v);
                  },
                ),
              ]),
            ),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('আর কোনো নোটিফিকেশন নেই')))
            else
              for (final t in list)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withAlpha(14)),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primary.withAlpha(24),
                      child: Icon(Icons.notifications_none, color: primary),
                    ),
                    title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
                  ),
                ),
          ]);
        },
      ),
    );
  }
}
