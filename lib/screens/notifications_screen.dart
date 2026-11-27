import 'package:flutter/material.dart';
import '../api.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../notifications.dart';
import '../sys_notify.dart';
import '../util.dart';
import '../widgets.dart';

/// নোটিফিকেশন ট্যাব: নতুন খবর/ভিডিওর নোটিফিকেশন চালু-বন্ধের সুইচ + অ্যাডমিনের ব্রেকিং নিউজ।
class NotificationsScreen extends StatefulWidget {
  final bool inShell;
  const NotificationsScreen({super.key, this.inShell = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _on = true;
  final ScrollController _sc = ScrollController();
  VoidCallback? _unRe;
  bool _osOn = true; // ফোনের সেটিংসে অ্যাপের নোটিফিকেশন চালু আছে কিনা

  Future<void> _checkOs() async {
    final v = await SysNotify.enabled();
    if (mounted) setState(() => _osOn = v);
  }

  @override
  void initState() {
    super.initState();
    if (widget.inShell) _unRe = TabNav.onReselect('notifications', () => TabNav.scrollTop(_sc));
    Notifier.loadHistory();
    Notifier.checkNew();
    _checkOs();
    Notifier.isOn().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  @override
  void dispose() {
    _unRe?.call();
    _sc.dispose();
    super.dispose();
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
          return ListView(controller: _sc, padding: const EdgeInsets.only(bottom: 24), children: [
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
            if (!_osOn)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.shade700)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ফোনে এই অ্যাপের নোটিফিকেশন বন্ধ আছে', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'তাই নতুন খবর এলেও ফোনে জানাতে পারছে না। নিচের বাটনে চাপুন। তাতে না হলে: ফোনের সেটিংস → অ্যাপ → আমার সকাল ২৪ → নোটিফিকেশন চালু করুন।',
                    style: TextStyle(height: 1.4, fontSize: 13.5),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      await SysNotify.requestPermission();
                      await _checkOs();
                    },
                    child: const Text('নোটিফিকেশন চালু করুন'),
                  ),
                ]),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await SysNotify.showTest();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'টেস্ট নোটিফিকেশন পাঠানো হয়েছে — ওপরে নোটিফিকেশন বারে দেখুন।' : 'নোটিফিকেশন দেখানো যায়নি। ফোনের সেটিংস দেখুন।')));
                    _checkOs();
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('টেস্ট নোটিফিকেশন পাঠান'),
                ),
              ),
            ValueListenableBuilder<List<NotifEntry>>(
              valueListenable: Notifier.history,
              builder: (context, hist, _) => Column(children: [
                for (final e in hist)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withAlpha(14)),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Notifier.open(e.data),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 74,
                              height: 56,
                              child: Stack(fit: StackFit.expand, children: [
                                NetImage(e.thumb),
                                if (e.isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 26)),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.isVideo ? 'নতুন ভিডিও' : 'নতুন খবর',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: primary)),
                              const SizedBox(height: 2),
                              Text(e.title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
                              const SizedBox(height: 2),
                              Text(timeAgo(e.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                if (hist.isEmpty && list.isEmpty)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('এখনো কোনো নোটিফিকেশন নেই'))),
              ]),
            ),
            if (list.isNotEmpty)
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
