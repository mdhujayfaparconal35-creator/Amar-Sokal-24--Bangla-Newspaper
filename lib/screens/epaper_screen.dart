import 'dart:async';
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

/// ই-পেপার সাইটের ওপরের অংশ (লোগো, সোশ্যাল আইকন, মেনু বার) ও নিচের ফুটার লুকানোর স্ক্রিপ্ট।
/// সাইটের ক্লাস/আইডি না জেনেই কাজ করে: পেজের নিচের "টেক্সট কাটিং" অংশটাকে মূল লেখা ধরে,
/// তার বাইরের যে ব্লকে "অনলাইন জরিপ" / "ই-কমার্স" / "All rights reserved" লেখা আছে সেই ব্লক লুকায়।
/// মূল অংশ (পাতার নম্বর, তারিখ, পেপারের ছবি) না পেলে কিছুই লুকায় না।
const String _hideJs = r'''
(function(){
  function all(t){
    var out=[],w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null),n;
    while(n=w.nextNode()){
      var p=n.parentElement;
      if(p&&n.nodeValue.indexOf(t)>=0&&!/^(SCRIPT|STYLE|NOSCRIPT)$/.test(p.tagName)) out.push(p);
    }
    return out;
  }
  var m=(all('টেক্সট কাটিং')[0])||(all('ফুল পেজ কাটিং')[0])||(all('ছবি কাটিং')[0]);
  if(!m) return false;
  ['অনলাইন জরিপ','ই-কমার্স','All rights reserved'].forEach(function(t){
    all(t).forEach(function(e){
      while(e.parentElement&&e.parentElement!==document.body&&!e.parentElement.contains(m)){e=e.parentElement;}
      if(e===document.body||e.contains(m)) return;
      e.style.setProperty('display','none','important');
    });
  });
  return true;
})();
''';

class _EpaperScreenState extends State<EpaperScreen> {
  Timer? _hideTimer;

  /// পেজ লোড হওয়ার পর (সাইট পরে কিছু অংশ আঁকে) কয়েকবার চালানো হয়
  void _hideChrome() {
    _hideTimer?.cancel();
    var n = 0;
    _hideTimer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (!mounted || ++n > 10) {
        t.cancel();
        return;
      }
      _c.runJavaScript(_hideJs).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

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
        onPageFinished: (_) => _hideChrome(),
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
