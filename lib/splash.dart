import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api.dart';
import 'config.dart';

/// অ্যাপ খুললে প্রথমে গোল লোগো: ছোট থেকে জুম-ইন হয়ে একটু বড় হয়, তারপর নরমভাবে জুম-আউট হয়ে
/// নিজের জায়গায় বসে। এই ফাঁকে পেছনে হোমের খবর আগেভাগে লোড হয়ে যায়; শেষে মূল অ্যাপে ফেড হয়।
class SplashGate extends StatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    // হোমের ডাটা আগেভাগে আনা (Api নিজেই ক্যাশ রাখে), ভুল হলে চুপচাপ
    Api.home().then((_) {}).catchError((_) {});
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _splash() {
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.25).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 45),
    ]).animate(_c);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.3, curve: Curves.easeOut));
    final text = CurvedAnimation(parent: _c, curve: const Interval(0.55, 0.9, curve: Curves.easeOutCubic));
    return Scaffold(
      key: const ValueKey('splash'),
      backgroundColor: AppConfig.brand,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.05, colors: [Color(0xFF22349A), AppConfig.brand]),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final ring = Curves.easeOut.transform(_c.value);
              return SizedBox(
                width: 260,
                height: 260,
                child: Stack(alignment: Alignment.center, children: [
                  // ছড়িয়ে পড়া আলোর বলয়
                  Opacity(
                    opacity: (1 - ring).clamp(0.0, 1.0) * 0.55 * fade.value,
                    child: Container(
                      width: 150 + 100 * ring,
                      height: 150 + 100 * ring,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                    ),
                  ),
                  Opacity(
                    opacity: fade.value,
                    child: Transform.scale(
                      scale: scale.value,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(color: Colors.white.withAlpha(70), blurRadius: 34, spreadRadius: 2),
                            BoxShadow(color: Colors.black.withAlpha(90), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover)),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 8),
          FadeTransition(
            opacity: text,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(text),
              child: Column(children: const [
                Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                SizedBox(height: 6),
                Text('amarsokal24.com', style: TextStyle(color: Colors.white60, fontSize: 14, letterSpacing: 0.6)),
              ]),
            ),
          ),
          const SizedBox(height: 36),
          FadeTransition(
            opacity: text,
            child: SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => LinearProgressIndicator(
                    value: math.min(1.0, _c.value * 1.05),
                    minHeight: 3,
                    color: const Color(0xFFFFB300),
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      child: _done ? KeyedSubtree(key: const ValueKey('app'), child: widget.child) : _splash(),
    );
  }
}
