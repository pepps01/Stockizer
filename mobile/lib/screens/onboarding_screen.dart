import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/strategy.dart';
import '../theme.dart';
import '../widgets/badges.dart';
import '../widgets/brand_mark.dart';
import '../widgets/flag.dart';
import '../widgets/motion.dart';

enum OnboardingExit { register, login }

/// Three-page introduction to the pipeline: Selector → Optimizer → Adviser.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final ValueChanged<OnboardingExit> onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      step: 'Selector',
      title: 'Rank the world’s markets',
      body:
          '37 exchanges across 34 countries — from New York and London to Lagos, Nairobi and Riyadh. '
          'Rank an exchange’s stocks by Sharpe, return or momentum and keep the top N.',
      art: _SelectorArt(),
    ),
    _PageData(
      step: 'Optimizer',
      title: 'Tune the algebra, then prove it',
      body:
          'Stockiser tunes five signal parameters on a training period, then tests them on the unseen period '
          'that follows — always compared with simply buying and holding.',
      art: _OptimizerArt(),
    ),
    _PageData(
      step: 'Adviser',
      title: 'Live signals, your decision',
      body:
          'Monitor tickers at the interval you choose. Green BUY, red SELL, orange HOLD — pushed to you in real time. '
          'Stockiser never places trades; you act through your own broker.',
      art: _AdviserArt(),
    ),
  ];

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() => _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  const BrandMark(size: 30),
                  const SizedBox(width: 10),
                  const Text('Stockiser', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (!_isLast)
                    TextButton(
                      onPressed: () => widget.onDone(OnboardingExit.login),
                      style: TextButton.styleFrom(foregroundColor: p.mutedForeground),
                      child: const Text('Skip'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) {
                  Haptics.tick();
                  setState(() => _page = i);
                },
                itemBuilder: (context, i) => _OnboardingPage(data: _pages[i], index: i),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 6,
                    height: 4,
                    decoration: BoxDecoration(color: i == _page ? p.ink : p.border, borderRadius: BorderRadius.circular(99)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLast
                    ? Column(
                        key: const ValueKey('last'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(onPressed: () => widget.onDone(OnboardingExit.register), child: const Text('Create an account')),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () => widget.onDone(OnboardingExit.login),
                            child: const Text('I already have an account'),
                          ),
                        ],
                      )
                    : SizedBox(
                        key: const ValueKey('next'),
                        width: double.infinity,
                        child: FilledButton(onPressed: _next, child: const Text('Next')),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  const _PageData({required this.step, required this.title, required this.body, required this.art});

  final String step;
  final String title;
  final String body;
  final Widget art;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.index});

  final _PageData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(24)),
                // Fixed design canvas, scaled to whatever width the phone has.
                child: FittedBox(child: SizedBox(width: 340, child: data.art)),
              ),
              const SizedBox(height: 32),
              Text(
                '0${index + 1} · ${data.step.toUpperCase()}',
                style: labelCaps(p).copyWith(color: p.brand),
              ),
              const SizedBox(height: 12),
              Text(data.title, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300, height: 1.1, letterSpacing: -0.8)),
              const SizedBox(height: 12),
              Text(data.body, style: TextStyle(fontSize: 16, height: 1.55, color: p.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- illustrations (composed from widgets, no image assets) ----

class _SelectorArt extends StatelessWidget {
  const _SelectorArt();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const rows = [('US', 'NVDA', 0.92), ('NG', 'DANGCEM', 0.78), ('GB', 'AZN', 0.64), ('JP', '7203', 0.51)];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 120 + 110 * i),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.mutedForeground),
                    ),
                    const SizedBox(width: 10),
                    Flag(code: rows[i].$1, size: 24),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: Text(rows[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: rows[i].$3),
                          duration: Duration(milliseconds: 900 + 120 * i),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) =>
                              LinearProgressIndicator(value: v, minHeight: 7, backgroundColor: p.surfaceMuted, color: p.brand),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptimizerArt extends StatelessWidget {
  const _OptimizerArt();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final chip in ['fast = 12', 'slow = 48', 'window = 20', 'w = 0.62', 'θ = 0.18'])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(99)),
                  child: Text(chip, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: Container(
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(12),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOutCubic,
                builder: (context, t, _) => CustomPaint(
                  painter: _CurvesPainter(strategy: p.brand, hold: p.mutedForeground, split: p.border, progress: t),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvesPainter extends CustomPainter {
  _CurvesPainter({required this.strategy, required this.hold, required this.split, this.progress = 1});

  final Color strategy;
  final Color hold;
  final Color split;
  final double progress;

  Path _partial(Path path) {
    final out = Path();
    for (final metric in path.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * progress), Offset.zero);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Path curve(double Function(double t) f) {
      final path = Path();
      for (var i = 0; i <= 60; i++) {
        final t = i / 60;
        final point = Offset(t * size.width, size.height * (1 - f(t)));
        i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
      }
      return path;
    }

    final splitX = size.width * 0.7;
    canvas.drawLine(
      Offset(splitX, 0),
      Offset(splitX, size.height),
      Paint()
        ..color = split
        ..strokeWidth = 1.5,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_partial(curve((t) => 0.3 + 0.25 * t + 0.08 * math.sin(t * 14))), stroke..color = hold.withValues(alpha: 0.7));
    canvas.drawPath(_partial(curve((t) => 0.25 + 0.6 * t + 0.05 * math.sin(t * 9))), stroke..color = strategy);
  }

  @override
  bool shouldRepaint(covariant _CurvesPainter old) => old.progress != progress || old.strategy != strategy || old.hold != hold;
}

class _AdviserArt extends StatelessWidget {
  const _AdviserArt();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const items = [
      ('SHOP', SignalType.buy, 'Trend up 1.4σ, not stretched'),
      ('RY', SignalType.hold, 'Inside the ±θ band'),
      ('SAFCOM', SignalType.sell, 'Trend down, stretched above mean'),
    ];
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, (symbol, type, reason)) in items.indexed)
            FadeSlideIn(
              delay: Duration(milliseconds: 150 + 260 * i),
              offset: 22,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: SignalBadge.colors(p, type).$1,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(reason, style: TextStyle(fontSize: 11.5, color: p.mutedForeground)),
                            ],
                          ),
                        ),
                      ),
                      SignalBadge(type: type, size: BadgeSize.sm),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
