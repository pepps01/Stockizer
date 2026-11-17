import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../theme.dart';

/// Small, consistent haptics. Selection ticks for choices and scrubbing,
/// a light impact for primary actions, a medium one for arriving signals.
abstract final class Haptics {
  static void tick() => HapticFeedback.selectionClick();
  static void tap() => HapticFeedback.lightImpact();
  static void alert() => HapticFeedback.mediumImpact();
}

/// Fades and lifts its child into place once, after [delay] — used to stagger
/// dashboard sections and list rows so screens settle in rather than pop.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero, this.offset = 14});

  final Widget child;
  final Duration delay;
  final double offset;

  /// Delay for the [index]th item of a staggered list (capped so long lists don't drag).
  static Duration stagger(int index, {int stepMs = 45}) => Duration(milliseconds: stepMs * index.clamp(0, 8));

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
      ),
    );
  }
}

/// A price that briefly flashes green or red when a live tick moves it,
/// and rolls smoothly to the new value.
class TickingPrice extends StatefulWidget {
  const TickingPrice({super.key, required this.value, this.style, this.digits, this.suffix});

  final double? value;
  final TextStyle? style;
  final int? digits;
  final String? suffix;

  @override
  State<TickingPrice> createState() => _TickingPriceState();
}

class _TickingPriceState extends State<TickingPrice> with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late double? _from = widget.value;
  int _direction = 0;

  @override
  void didUpdateWidget(TickingPrice old) {
    super.didUpdateWidget(old);
    final prev = old.value;
    final next = widget.value;
    if (prev != null && next != null && next != prev) {
      _from = prev;
      _direction = next > prev ? 1 : -1;
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final value = widget.value;
    final base = (widget.style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    if (value == null) return Text('—', style: base);
    return AnimatedBuilder(
      animation: _flash,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_flash.value);
        final shown = _from == null || !_flash.isAnimating ? value : _from! + (value - _from!) * (t * 3).clamp(0.0, 1.0);
        final tint = _direction > 0 ? p.gain : p.loss;
        final glow = _flash.isAnimating ? (1 - t) : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16 * glow),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${formatNumber(shown, widget.digits)}${widget.suffix ?? ''}',
            style: base.copyWith(color: glow > 0.05 ? Color.lerp(base.color ?? p.foreground, tint, glow) : base.color),
          ),
        );
      },
    );
  }
}

/// Shimmering placeholder sweep shared by every loading skeleton.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final x = -1.5 + 3 * _c.value;
          return LinearGradient(
            begin: Alignment(x - 0.6, 0),
            end: Alignment(x + 0.6, 0),
            colors: [p.surfaceMuted, p.surface.withValues(alpha: 0.9), p.surfaceMuted],
            stops: const [0.2, 0.5, 0.8],
          ).createShader(rect);
        },
        child: child,
      ),
    );
  }
}

/// A softly pulsing dot — "live" indicators and the newest signal.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * (1 + 1.4 * _c.value),
              height: s * (1 + 1.4 * _c.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scales down slightly while pressed — gives cards and tiles a physical feel.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, required this.onTap, this.haptic = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptics.tap();
              widget.onTap!();
            },
      child: AnimatedScale(scale: _down ? 0.97 : 1, duration: const Duration(milliseconds: 110), child: widget.child),
    );
  }
}
