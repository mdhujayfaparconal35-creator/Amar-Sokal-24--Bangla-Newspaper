import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';
import '../dynamic_ui.dart';
import '../lang.dart';
import '../util.dart';
import 'home_screen.dart';
import 'web_page_screen.dart';

/// "হোম" ট্যাব: বাংলা মোডে সাধারণ হোম, ইংরেজি মোডে ইংরেজি সংস্করণের সাইট (অ্যাপের ভেতরেই)
class HomeSwitch extends StatelessWidget {
  const HomeSwitch({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Lang.en,
        builder: (_, en, __) => en ? const EnglishHome() : const HomeScreen(),
      );
}

class EnglishHome extends StatefulWidget {
  /// ব্যাক চাপলে আগে ইংরেজি সাইটের ভেতরে পেছনে যায়; গেলে true
  static Future<bool> Function()? tryBack;
  const EnglishHome({super.key});

  @override
  State<EnglishHome> createState() => _EnglishHomeState();
}

class _EnglishHomeState extends State<EnglishHome> {
  late final WebViewController _c;
  Timer? _timer;
  int _progress = 0;
  bool _error = false;
  late final Future<bool> Function() _back;

  void _hide() {
    _timer?.cancel();
    var n = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!mounted || ++n > 16) {
        t.cancel();
        return;
      }
      _c.runJavaScript(kWebHideJs).catchError((_) {});
    });
  }

  @override
  void initState() {
    super.initState();
    final host = Uri.parse(AppConfig.englishUrl).host;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          final scheme = u?.scheme ?? '';
          if (scheme != 'http' && scheme != 'https' && scheme != 'about' && scheme != 'data' && scheme != 'javascript' && scheme != 'blob') {
            if (scheme == 'tel' || scheme == 'mailto' || scheme == 'sms' || scheme == 'whatsapp') openExternal(r.url);
            return NavigationDecision.prevent;
          }
          // অন্য সাইটের লিংক অ্যাপের আলাদা পেজে (তবুও অ্যাপের ভেতরেই)
          if (u != null && u.host.isNotEmpty && u.host != host && !r.url.startsWith('about:')) {
            openLink(r.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _error = false);
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) => _hide(),
        onWebResourceError: (e) {
          if (mounted && (e.isForMainFrame ?? true)) setState(() => _error = true);
        },
      ))
      ..loadRequest(Uri.parse(AppConfig.englishUrl));
    _back = () async {
      if (await _c.canGoBack()) {
        await _c.goBack();
        return true;
      }
      return false;
    };
    EnglishHome.tryBack = _back;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (EnglishHome.tryBack == _back) EnglishHome.tryBack = null;
    super.dispose();
  }

  void _reload() {
    setState(() => _error = false);
    _c.loadRequest(Uri.parse(AppConfig.englishUrl));
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      inShell: true,
      body: Stack(children: [
        if (_error)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Could not load the page'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _reload, child: const Text('Try again')),
            ]),
          )
        else
          WebViewWidget(controller: _c),
        if (!_error && _progress < 100) LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
      ]),
    );
  }
}
