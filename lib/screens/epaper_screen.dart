import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';
import '../dynamic_ui.dart';
import '../models.dart';

/// ই-পেপার ট্যাব: অ্যাপের ভেতরেই epaper.amarsokal24.com দেখায় (ওয়েবসাইটে আপডেট হলে এখানেও আপডেট দেখা যায়)।
class EpaperScreen extends StatefulWidget {
  final bool inShell;
  const EpaperScreen({super.key, this.inShell = false});

  @override
  State<EpaperScreen> createState() => _EpaperScreenState();
}

class _EpaperScreenState extends State<EpaperScreen> {
  late final WebViewController _c;
  int _progress = 0;
  bool _error = false;

  String get _url {
    final u = AppSettings.current.epaper.url;
    return u.startsWith('https://') ? u : AppConfig.epaperUrl;
  }

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onWebResourceError: (e) {
          if (mounted && (e.isForMainFrame ?? true)) setState(() => _error = true);
        },
      ))
      ..loadRequest(Uri.parse(_url));
  }

  void _reload() {
    setState(() => _error = false);
    _c.loadRequest(Uri.parse(_url));
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: widget.inShell,
      title: const Text('ই-পেপার'),
      body: Stack(children: [
        if (_error)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('ই-পেপার লোড করা যায়নি'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _reload, child: const Text('আবার চেষ্টা করুন')),
            ]),
          )
        else
          WebViewWidget(controller: _c),
        if (!_error && _progress < 100) LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
      ]),
    );
  }
}
