import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';
import '../dynamic_ui.dart';
import '../util.dart';

const String _mobileUa = 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

/// "রিলস" ট্যাব: ফেসবুক পেজের রিলস অ্যাপের ভেতরেই খোলে। একটি রিলসে ট্যাপ করে ওপরে স্ক্রল করলে একটার পর একটা আসে।
class ReelsScreen extends StatefulWidget {
  final bool inShell;
  const ReelsScreen({super.key, this.inShell = false});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late final WebViewController _c;
  int _progress = 0;
  bool _error = false;
  bool _hint = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUa)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          final s = Uri.tryParse(r.url)?.scheme ?? '';
          // ফেসবুকের "অ্যাপে খুলুন" (fb://, intent://) আটকে অ্যাপের ভেতরেই থাকা
          if (s != 'http' && s != 'https' && s != 'about' && s != 'data' && s != 'javascript' && s != 'blob') return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _error = false);
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) {
          _t?.cancel();
          _t = Timer(const Duration(seconds: 7), () {
            if (mounted) setState(() => _hint = false);
          });
        },
        onWebResourceError: (e) {
          if (mounted && (e.isForMainFrame ?? true)) setState(() => _error = true);
        },
      ))
      ..loadRequest(Uri.parse(AppConfig.reelsUrl));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _reload() {
    setState(() => _error = false);
    _c.loadRequest(Uri.parse(AppConfig.reelsUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
      appBar: appHeader(context, back: !widget.inShell),
      body: Stack(children: [
        if (_error)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.white54),
              const SizedBox(height: 12),
              const Text('রিলস লোড করা যায়নি', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              FilledButton(onPressed: _reload, child: const Text('আবার চেষ্টা করুন')),
              const SizedBox(height: 6),
              TextButton(onPressed: () => openExternal(AppConfig.reelsUrl), child: const Text('ফেসবুকে খুলুন')),
            ]),
          )
        else
          WebViewWidget(controller: _c),
        if (!_error && _progress < 100) LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100, minHeight: 3),
        if (_hint && !_error)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.black.withAlpha(190), borderRadius: BorderRadius.circular(22)),
                child: const Text('একটি রিলসে ট্যাপ করুন, তারপর ওপরে স্ক্রল করলে পরের রিলস আসবে', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
      ]),
    );
  }
}
