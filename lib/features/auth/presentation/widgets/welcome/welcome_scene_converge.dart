import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_common.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_logo_group.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_assets.dart';

/// Scene 6: class badges and honors appear around the logo, fly into it, the
/// rings burst and the logo grows and holds. The logo carries the Hero tag
/// that lands on the login screen.
class WelcomeSceneConverge extends StatelessWidget {
  const WelcomeSceneConverge({super.key, required this.active});

  final bool active;

  static const Offset _center = Offset(201, 220);
  static const double _loop = 7;
  static const double _baseSize = 120;
  static const double _flySize = 58;
  static const double _ringBorder = 3;
  static const double _ringRadiusRatio = 0.3;
  static const Curve _flyCurve = Cubic(0.55, 0, 0.75, 0.2);

  static const List<String> _classes = [
    'AV-02',
    'CQ-01',
    'GM-01',
    'CQ-04',
    'AV-05',
    'CQ-06',
    'AV-01',
    'CQ-03',
  ];
  static const List<int> _honors = [1, 4, 8, 12, 15, 17];

  @override
  Widget build(BuildContext context) {
    return WelcomeSceneFrame(
      child: WelcomeStage(
        active: active,
        builder: (context, clock) {
          if (clock.reduced) {
            return Stack(
              clipBehavior: Clip.none,
              children: const [
                WelcomeLogoGroup(
                  center: _center,
                  scale: 1,
                  glowFactor: 2,
                  hero: true,
                ),
              ],
            );
          }
          final t = clock.t;
          final appear = wProg(t, 0, 1.0);
          final phase = (t % _loop) / _loop;
          final absorb = wKeyframes(phase, const [
            (0, 1),
            (0.54, 1),
            (0.6, 1.62),
            (0.66, 1.44),
            (0.92, 1.44),
            (1, 1),
          ]);
          final pulse = wPingPong(math.max(0, t - 1), _loop / 2);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              _ring(t, 0, AppColors.loginBrandBlue),
              _ring(t, 0.2, AppColors.loginBrandGold),
              WelcomeLogoGroup(
                center: _center,
                scale: _baseSize / WelcomeLogoGroup.logoSize * absorb,
                opacity: Curves.easeOut.transform(appear),
                glowFactor: 2,
                glowScale: wLerp(0.9, 1.12, pulse),
                glowOpacity: wLerp(0.7, 1, pulse),
                hero: true,
              ),
              ..._flyers(t),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double t, double delay, Color color) {
    final p = t < delay ? 0.0 : (((t - delay) % _loop) / _loop);
    final opacity = wKeyframes(
      p,
      const [(0, 0), (0.55, 0), (0.59, 0.85), (0.78, 0), (1, 0)],
      curve: Curves.linear,
    );
    final scale =
        wKeyframes(p, const [(0, 1), (0.55, 1), (0.78, 2.3), (1, 2.3)]);
    return Positioned(
      left: _center.dx - _baseSize / 2,
      top: _center.dy - _baseSize / 2,
      width: _baseSize,
      height: _baseSize,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: _ringBorder),
              borderRadius: BorderRadius.circular(_baseSize * _ringRadiusRatio),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _flyers(double t) {
    final flyers = <Widget>[];
    for (var i = 0; i < _classes.length; i++) {
      final angle = i / _classes.length * 2 * math.pi + 0.2;
      flyers.add(
        _flyer(
          t,
          (i % 6) * 0.12,
          Offset(math.cos(angle) * 165 * 0.95, math.sin(angle) * 165 * 1.05),
          welcomeClassBadge(_classes[i], _flySize),
        ),
      );
    }
    for (var i = 0; i < _honors.length; i++) {
      final angle = i / _honors.length * 2 * math.pi;
      flyers.add(
        _flyer(
          t,
          (i % 6) * 0.12,
          Offset(math.cos(angle) * 100 * 0.95, math.sin(angle) * 100 * 1.05),
          welcomeHonor(_honors[i], _flySize),
        ),
      );
    }
    return flyers;
  }

  Widget _flyer(double t, double delay, Offset from, Widget image) {
    final p = t < delay ? 0.0 : (((t - delay) % _loop) / _loop);
    final opacity = wKeyframes(
      p,
      const [(0, 0), (0.08, 1), (0.24, 1), (0.54, 0.9), (0.57, 0), (1, 0)],
      curve: _flyCurve,
    );
    if (opacity <= 0) return const SizedBox.shrink();
    final scale = wKeyframes(
      p,
      const [
        (0, 0.6),
        (0.08, 1),
        (0.24, 1),
        (0.54, 0.25),
        (0.57, 0.1),
        (1, 0.1)
      ],
      curve: _flyCurve,
    );
    final travel = wKeyframes(
      p,
      const [(0, 1), (0.24, 1), (0.54, 0), (1, 0)],
      curve: _flyCurve,
    );
    return Positioned(
      left: _center.dx + from.dx * travel - _flySize / 2,
      top: _center.dy + from.dy * travel - _flySize / 2,
      width: _flySize,
      height: _flySize,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: image),
      ),
    );
  }
}
