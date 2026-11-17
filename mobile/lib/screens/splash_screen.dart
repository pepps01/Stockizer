import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_mark.dart';

/// Brand splash shown while the stored session is restored. The native launch
/// background is the same indigo, so the hand-over is seamless.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final Animation<double> _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.35, 1, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.light.ink,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            ScaleTransition(scale: _scale, child: const BrandMark(size: 96, inverted: true)),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fade,
              child: const Column(
                children: [
                  Text('Stockiser', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  SizedBox(height: 6),
                  Text('Signals, not noise.', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 16, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
            const Spacer(flex: 3),
            FadeTransition(
              opacity: _fade,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
            const SizedBox(height: 18),
            FadeTransition(
              opacity: _fade,
              child: const Text('SELECT · OPTIMIZE · ADVISE', style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
