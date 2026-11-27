import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../dynamic_ui.dart';
import '../util.dart';

/// ওয়েবসাইটের ওপরের হেডার/মেনু ও নিচের ফুটার লুকানোর স্ক্রিপ্ট (যেকোনো সাইটে চলে)।
/// সাইটের ক্লাস না জেনেই: header/footer ট্যাগ, ওপরে আটকে থাকা বার, "স্বত্ব/©/All rights reserved" ব্লক লুকায়।
/// মূল লেখা (main/article) কখনো লুকায় না।
const String kWebHideJs = r'''
(function(){
  if(!document.body) return;
  var H=function(e){ if(e&&e!==document.body&&e!==document.documentElement) e.style.setProperty('display','none','important'); };
  var inMain=function(e){ return !!e.closest('main,article,[role=main]'); };
  var W=window.innerWidth||360;
  document.querySelectorAll('header,footer,[role=banner],[role=contentinfo],#header,#footer,#masthead,#colophon,.site-header,.site-footer,.main-header,.main-footer,.footer-area,.header-area,.topbar,#topbar').forEach(function(e){
    if(!inMain(e)) H(e);
  });
  document.querySelectorAll('nav').forEach(function(e){
    if(inMain(e)) return;
    var r=e.getBoundingClientRect();
    if(r.top<140 && r.width>=W*0.8) H(e);
  });
  document.querySelectorAll('body *').forEach(function(e){
    var cs=getComputedStyle(e);
    if(cs.position==='fixed'||cs.position==='sticky'){
      var r=e.getBoundingClientRect();
      if(r.top<=5 && r.height>0 && r.height<170 && r.width>=W*0.8 && !inMain(e)) H(e);
    }
  });
  var total=document.documentElement.scrollHeight;
  var walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null),n;
  var keys=['All rights reserved','Copyright','\u00A9','\u09B8\u09CD\u09AC\u09A4\u09CD\u09AC'];
  while(n=walker.nextNode()){
    var p=n.parentElement;
    if(!p||/^(SCRIPT|STYLE|NOSCRIPT)$/.test(p.tagName)) continue;
    var hit=false; for(var i=0;i<keys.length;i++){ if(n.nodeValue.indexOf(keys[i])>=0){hit=true;break;} }
    if(!hit) continue;
    var e=p;
    while(e.parentElement && e.parentElement!==document.body){
      var pr=e.parentElement, r=pr.getBoundingClientRect(), top=r.top+(window.scrollY||0);
      if(top<total*0.55 || r.height>800 || pr.querySelector('main,article,[role=main]')) break;
      e=pr;
    }
    if(e!==document.body && !inMain(e)) H(e);
  }
  document.body.style.setProperty('padding-top','0','important');
})();
''';

/// ই-পেপার সাইটের নিজস্ব অতিরিক্ত অংশ (ই-পেপার ট্যাবের মতোই)
const String _epaperJs = r'''
(function(){
  function all(t){
    var out=[],w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,null),n;
    while(n=w.nextNode()){
      var p=n.parentElement;
      if(p&&n.nodeValue.indexOf(t)>=0&&!/^(SCRIPT|STYLE|NOSCRIPT)$/.test(p.tagName)) out.push(p);
    }
    return out;
  }
  var m=(all('\u099F\u09C7\u0995\u09CD\u09B8\u099F \u0995\u09BE\u099F\u09BF\u0982')[0]);
  if(!m) return;
  ['\u0985\u09A8\u09B2\u09BE\u0987\u09A8 \u099C\u09B0\u09BF\u09AA','\u0987-\u0995\u09AE\u09BE\u09B0\u09CD\u09B8','All rights reserved'].forEach(function(t){
    all(t).forEach(function(e){
      while(e.parentElement&&e.parentElement!==document.body&&!e.parentElement.contains(m)){e=e.parentElement;}
      if(e===document.body||e.contains(m)) return;
      e.style.setProperty('display','none','important');
    });
  });
})();
''';

/// অ্যাপের ভেতরেই ওয়েব পেজ খোলে: অ্যাপের নিজস্ব হেডার (লোগো, আইকন ট্যাব) থাকে,
/// ওয়েবসাইটের নিজের হেডার-ফুটার লুকানো থাকে (ই-পেপার ট্যাবের মতো)।
class WebPageScreen extends StatefulWidget {
  final String url;
  final String title;
  const WebPageScreen({super.key, required this.url, this.title = ''});

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _c;
  Timer? _timer;
  int _progress = 0;
  bool _error = false;

  bool get _isEpaper => widget.url.contains('epaper.');

  void _hide() {
    _timer?.cancel();
    var n = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      if (!mounted || ++n > 16) {
        t.cancel();
        return;
      }
      _c.runJavaScript(kWebHideJs).catchError((_) {});
      if (_isEpaper) _c.runJavaScript(_epaperJs).catchError((_) {});
    });
  }

  @override
  void initState() {
    super.initState();
    TabNav.openLinks++;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          final scheme = u?.scheme ?? '';
          // শুধু ফোন/মেইল/মেসেজ/হোয়াটসঅ্যাপ অন্য অ্যাপে; বাকি অজানা স্কিম (fb://, intent:// ইত্যাদি) আটকে অ্যাপের ভেতরেই থাকে
          if (scheme != 'http' && scheme != 'https' && scheme != 'about' && scheme != 'data' && scheme != 'javascript' && scheme != 'blob') {
            if (scheme == 'tel' || scheme == 'mailto' || scheme == 'sms' || scheme == 'whatsapp') openExternal(r.url);
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
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _timer?.cancel();
    TabNav.openLinks = TabNav.openLinks > 0 ? TabNav.openLinks - 1 : 0;
    // পেজ বন্ধ হলে (আর কোনো লিংক-পেজ খোলা না থাকলে) হাইলাইট আবার বর্তমান ট্যাবে ফেরে
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (TabNav.openLinks == 0 && TabNav.current.value.startsWith('link:')) TabNav.current.value = TabNav.shellCur;
    });
    super.dispose();
  }

  void _reload() {
    setState(() => _error = false);
    _c.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _c.canGoBack()) {
          await _c.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: appHeader(context, back: true),
        body: Stack(children: [
          if (_error)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('পেজটি লোড করা যায়নি'),
                const SizedBox(height: 8),
                FilledButton(onPressed: _reload, child: const Text('আবার চেষ্টা করুন')),
              ]),
            )
          else
            WebViewWidget(controller: _c),
          if (!_error && _progress < 100) LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100),
        ]),
      ),
    );
  }
}
