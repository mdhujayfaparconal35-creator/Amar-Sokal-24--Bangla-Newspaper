import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../api.dart';
import '../config.dart';
import '../dynamic_ui.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// ভিডিও অ্যাপের ভেতরেই চলে (ইউটিউব এমবেড, ফুলস্ক্রিনসহ)। নিচে শেয়ার ও আরও ভিডিও।
class VideoPlayerScreen extends StatefulWidget {
  final VideoItem video;
  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final String _id = youtubeId(widget.video.youtube);
  late final Future<List<VideoItem>> _more = Api.videos(page: 1);

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: appHeader(context, back: true),
      body: ListView(children: [
        if (_id.isNotEmpty)
          YoutubeWebPlayer(id: _id)
        else
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black, child: Center(child: Text('ভিডিওটি চালানো যাচ্ছে না', style: TextStyle(color: Colors.white)))),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(v.title, textAlign: TextAlign.start, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4)),
        ),
        if (v.date.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(bnDateTime(v.date), style: TextStyle(fontSize: 14, color: Theme.of(context).hintColor)),
          ),
        if (_id.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: ShareRow(title: v.title, link: 'https://www.youtube.com/watch?v=$_id'),
          ),
        const SectionTitle('আরও ভিডিও'),
        FutureBuilder<List<VideoItem>>(
          future: _more,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            final list = (snap.data ?? const <VideoItem>[]).where((e) => e.id != v.id).toList();
            return Column(children: [
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: VideoCard(e),
                ),
            ]);
          },
        ),
        const AppFooter(),
      ]),
    );
  }
}

/// ইউটিউব ভিডিও চালায়। ইউটিউব এমবেডের জন্য রেফারার/অরিজিন দরকার (না থাকলে "Video player configuration error" আসে),
/// তাই পেজটি সাইটের ঠিকানা (baseUrl) সহ লোড করা হয়।
class YoutubeWebPlayer extends StatefulWidget {
  final String id;
  const YoutubeWebPlayer({super.key, required this.id});

  @override
  State<YoutubeWebPlayer> createState() => _YoutubeWebPlayerState();
}

class _YoutubeWebPlayerState extends State<YoutubeWebPlayer> {
  late final WebViewController _c;
  bool _error = false;
  bool _fsOpen = false;
  void Function()? _fsHidden;

  String get _origin => Uri.parse(AppConfig.apiBase).origin;

  String get _html => '''
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}</style>
</head><body>
<iframe src="https://www.youtube.com/embed/${widget.id}?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=$_origin"
 allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen
 referrerpolicy="strict-origin-when-cross-origin"></iframe>
</body></html>''';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          // ভিডিওর ভেতরের লিংক (যেমন ইউটিউব লোগো) ট্যাপ করলে প্লেয়ার বদলাবে না, ইউটিউবে খুলবে
          if (r.isMainFrame) {
            final u = r.url;
            if (u.startsWith(_origin) || u.startsWith('about:') || u.startsWith('data:')) return NavigationDecision.navigate;
            openLink(u);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (e) {
          if (mounted && (e.isForMainFrame ?? true)) setState(() => _error = true);
        },
      ));
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      p.setMediaPlaybackRequiresUserGesture(false);
      // ফুলস্ক্রিন বাটন: ভিডিও আলাদা কালো পর্দায় আড়াআড়ি খোলে
      p.setCustomWidgetCallbacks(
        onShowCustomWidget: (Widget w, void Function() onHidden) => _enterFullscreen(w, onHidden),
        onHideCustomWidget: _exitFullscreen,
      );
    }
    _c.loadHtmlString(_html, baseUrl: '$_origin/');
  }

  void _enterFullscreen(Widget w, void Function() onHidden) {
    if (!mounted || _fsOpen) return;
    _fsOpen = true;
    _fsHidden = onHidden;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _restore();
        },
        child: Scaffold(backgroundColor: Colors.black, body: SizedBox.expand(child: w)),
      ),
    ));
  }

  /// ওয়েব পেজ নিজে ফুলস্ক্রিন থেকে বের হলে
  void _exitFullscreen() {
    if (!_fsOpen) return;
    _fsHidden = null; // ওয়েব নিজেই লুকিয়েছে, আবার জানানোর দরকার নেই
    if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
  }

  /// ব্যাক চাপলে: ওয়েবকে জানিয়ে স্বাভাবিক অবস্থায় ফেরে
  void _restore() {
    if (!_fsOpen) return;
    _fsOpen = false;
    final cb = _fsHidden;
    _fsHidden = null;
    cb?.call();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    if (_fsOpen) _restore();
    super.dispose();
  }

  void _retry() {
    setState(() => _error = false);
    _c.loadHtmlString(_html, baseUrl: '$_origin/');
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: _error
            ? ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('ভিডিওটি লোড করা যায়নি', style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _retry, child: const Text('আবার চেষ্টা করুন')),
                  ]),
                ),
              )
            : WebViewWidget(controller: _c),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => openYoutube(widget.id),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('ভিডিও না চললে ইউটিউবে দেখুন'),
        ),
      ),
    ]);
  }
}
