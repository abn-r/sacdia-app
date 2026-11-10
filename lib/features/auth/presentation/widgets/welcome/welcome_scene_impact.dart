import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_common.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_logo_group.dart';

/// Scene 1: the logo lands with a little overshoot, a shine sweeps across it
/// every few seconds, the glow breathes and four-point stars twinkle around.
class WelcomeSceneImpact extends StatelessWidget {
  const WelcomeSceneImpact({super.key, required this.active});

  final bool active;

  static const Offset _center = Offset(201, 220);
  static const double _loop = 3.4;
  static const double _loopStart = 1.0;
  static const double _twinkle = 2.6;
  static const Curve _landing = Cubic(0.2, 0.9, 0.25, 1.25);

  static const List<WelcomeSparkSpec> _sparks = [
    WelcomeSparkSpec(-128, -112, WelcomeSparkTone.gold, 0, 24),
    WelcomeSparkSpec(124, -96, WelcomeSparkTone.sky, 0.5, 18),
    WelcomeSparkSpec(-146, 26, WelcomeSparkTone.blue, 1.1, 16),
    WelcomeSparkSpec(136, 64, WelcomeSparkTone.gold, 1.6, 24),
    WelcomeSparkSpec(-44, -150, WelcomeSparkTone.sky, 0.8, 14),
    WelcomeSparkSpec(52, 146, WelcomeSparkTone.blue, 2, 18),
    WelcomeSparkSpec(-104, 118, WelcomeSparkTone.sky, 1.4, 14),
    WelcomeSparkSpec(100, -150, WelcomeSparkTone.gold, 2.3, 14),
    WelcomeSparkSpec(-150, -48, WelcomeSparkTone.gold, 1.9, 12),
    WelcomeSparkSpec(150, -10, WelcomeSparkTone.blue, 0.3, 12),
  ];

  @override
  Widget build(BuildContext context) {
    return WelcomeSceneFrame(
      child: WelcomeStage(
        active: active,
        builder: (context, clock) {
          final reduced = clock.reduced;
          final t = clock.t;
          final landing = reduced ? 1.0 : wProg(t, 0, 1.0);
          final eased = _landing.transform(landing);
          final scale = reduced ? 1.0 : wLerp(0.55, 1, eased);
          final opacity = reduced ? 1.0 : eased.clamp(0.0, 1.0);

          double? shine;
          var pulse = 0.0;
          if (!reduced && t >= _loopStart) {
            final phase = ((t - _loopStart) % _loop) / _loop;
            shine =
                wKeyframes(phase, const [(0, 1.1), (0.35, -0.7), (1, -0.7)]);
            pulse = wPingPong(t - _loopStart, _loop / 2);
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final spark in _sparks) _spark(spark, t, reduced),
              WelcomeLogoGroup(
                center: _center,
                scale: scale,
                opacity: opacity,
                glowFactor: 293 / WelcomeLogoGroup.logoSize,
                glowScale: wLerp(0.9, 1.12, pulse),
                glowOpacity: wLerp(0.7, 1, pulse),
                shine: shine,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _spark(WelcomeSparkSpec spec, double t, bool reduced) {
    var opacity = 0.8;
    var scale = 1.0;
    var turn = 0.0;
    if (!reduced) {
      if (t < spec.delay) {
        opacity = 0;
      } else {
        final p = ((t - spec.delay) % _twinkle) / _twinkle;
        opacity = wKeyframes(
          p,
          const [(0, 0), (0.45, 1), (0.7, 0), (1, 0)],
          curve: Curves.easeInOut,
        );
        scale = wKeyframes(
          p,
          const [(0, 0.2), (0.45, 1), (0.7, 0.4), (1, 0.2)],
          curve: Curves.easeInOut,
        );
        turn = wKeyframes(
          p,
          const [(0, 0), (0.45, 45), (0.7, 90), (1, 0)],
          curve: Curves.easeInOut,
        );
      }
    }
    final size = spec.size;
    return Positioned(
      left: _center.dx + spec.dx - size / 2,
      top: _center.dy + spec.dy - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: turn * math.pi / 180,
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              painter: WelcomeStarPainter(color: spec.color()),
            ),
          ),
        ),
      ),
    );
  }
}
