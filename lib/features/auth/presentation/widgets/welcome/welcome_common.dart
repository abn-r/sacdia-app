import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Design box every welcome scene is drawn in (the prototype's stage).
const Size kWelcomeDesignSize = Size(402, 440);

/// Time handed to a scene on every frame.
///
/// [t] is the number of seconds since the page became the visible one. With
/// reduced motion the scene is built once with [reduced] set and must draw its
/// final static composition.
class WelcomeClock {
  const WelcomeClock(this.t, {this.reduced = false});

  final double t;
  final bool reduced;
}

typedef WelcomeSceneBuilder = Widget Function(
  BuildContext context,
  WelcomeClock clock,
);

/// Owns the only Ticker of a scene. It runs while [active] (the visible page)
/// and motion is allowed, freezes when the page leaves and restarts from zero
/// when it comes back. There are no Timers: tests settle on their own.
class WelcomeStage extends StatefulWidget {
  const WelcomeStage({super.key, required this.active, required this.builder});

  final bool active;
  final WelcomeSceneBuilder builder;

  @override
  State<WelcomeStage> createState() => _WelcomeStageState();
}

class _WelcomeStageState extends State<WelcomeStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = SacMotion.reduceMotionOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(WelcomeStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shouldRun = widget.active && !_reduced;
    if (shouldRun && !_ticker.isActive) {
      _seconds.value = 0;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) {
      return RepaintBoundary(
        child: widget.builder(context, const WelcomeClock(0, reduced: true)),
      );
    }
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _seconds,
        builder: (context, t, _) => widget.builder(context, WelcomeClock(t)),
      ),
    );
  }
}

/// Scales the 402x440 design box to the space the page gives the stage, so
/// small phones keep the whole composition and nothing reaches the copy.
class WelcomeSceneFrame extends StatelessWidget {
  const WelcomeSceneFrame({super.key, required this.child});

  final Widget child;

  static const double _maxScale = 1.25;
  static const double _minScale = 0.4;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = math
                  .min(
                    constraints.maxWidth / kWelcomeDesignSize.width,
                    constraints.maxHeight / kWelcomeDesignSize.height,
                  )
                  .clamp(_minScale, _maxScale);
              return Center(
                child: SizedBox(
                  width: kWelcomeDesignSize.width * scale,
                  height: kWelcomeDesignSize.height * scale,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    clipBehavior: Clip.none,
                    child: SizedBox(
                      width: kWelcomeDesignSize.width,
                      height: kWelcomeDesignSize.height,
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 0..1 progress of [t] in the window [start, start + duration].
double wProg(double t, double start, double duration) =>
    ((t - start) / duration).clamp(0.0, 1.0);

double wLerp(double a, double b, double p) => a + (b - a) * p;

/// CSS-style keyframes: piecewise interpolation between `(position, value)`
/// pairs with [curve] on each interval; holds the first and last values.
double wKeyframes(
  double p,
  List<(double, double)> keys, {
  Curve curve = Curves.ease,
}) {
  if (p <= keys.first.$1) return keys.first.$2;
  for (var i = 1; i < keys.length; i++) {
    if (p <= keys[i].$1) {
      final a = keys[i - 1];
      final b = keys[i];
      final span = b.$1 - a.$1;
      if (span <= 0) return b.$2;
      return wLerp(a.$2, b.$2, curve.transform((p - a.$1) / span));
    }
  }
  return keys.last.$2;
}

/// Triangle wave 0..1..0 with the given full period, eased in and out.
/// Used for the gentle "bob" and the glow pulse.
double wPingPong(double t, double period) {
  final phase = (t / period) % 2.0;
  final tri = phase < 1 ? phase : 2 - phase;
  return Curves.easeInOut.transform(tri);
}

/// Radial brand-blue glow behind a logo.
class WelcomeGlow extends StatelessWidget {
  const WelcomeGlow({super.key, required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [_glowCenter, _glowEdge],
              stops: [0, 0.65],
            ),
          ),
        ),
      ),
    );
  }

  static final Color _glowCenter =
      AppColors.loginBrandBlue.withValues(alpha: 0.35);
  static final Color _glowEdge = AppColors.loginBrandBlue.withValues(alpha: 0);
}

/// Four-point star used for the twinkles.
class WelcomeStarPainter extends CustomPainter {
  const WelcomeStarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);
    final path = Path()..moveTo(0.5 * w, 0);
    void curve(double x1, double y1, double x2, double y2, double x, double y) {
      final a = p(x1, y1);
      final b = p(x2, y2);
      final c = p(x, y);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }

    curve(0.5333, 0.2917, 0.7083, 0.4667, 1, 0.5);
    curve(0.7083, 0.5333, 0.5333, 0.7083, 0.5, 1);
    curve(0.4667, 0.7083, 0.2917, 0.5333, 0, 0.5);
    curve(0.2917, 0.4667, 0.4667, 0.2917, 0.5, 0);
    path.close();

    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: color.a * 0.28),
    );
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.scale(0.72);
    canvas.translate(-w / 2, -h / 2);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(WelcomeStarPainter oldDelegate) =>
      oldDelegate.color != color;
}
