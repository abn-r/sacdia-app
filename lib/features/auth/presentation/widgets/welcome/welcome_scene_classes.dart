import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_assets.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_common.dart';

class _Badge {
  const _Badge(this.code, this.x, this.y, this.size);

  final String code;
  final double x;
  final double y;
  final double size;
}

/// Scene 2: the 13 class badges burst out of the centre in a 4-5-4 honeycomb
/// and bob; then everything but Viajero fades, Viajero flies to a progress card
/// whose five modules fill and get validated one by one. Loops.
class WelcomeSceneClasses extends StatelessWidget {
  const WelcomeSceneClasses({super.key, required this.active});

  final bool active;

  static const List<_Badge> _badges = [
    _Badge('AV-01', 69, 136, 88),
    _Badge('AV-02', 157, 136, 88),
    _Badge('AV-03', 245, 136, 88),
    _Badge('AV-04', 333, 136, 88),
    _Badge('AV-05', 25, 222, 88),
    _Badge('AV-06', 113, 222, 88),
    _Badge('GM-01', 201, 222, 104),
    _Badge('CQ-01', 289, 222, 88),
    _Badge('CQ-02', 377, 222, 88),
    _Badge('CQ-03', 69, 308, 88),
    _Badge('CQ-04', 157, 308, 88),
    _Badge('CQ-05', 245, 308, 88),
    _Badge('CQ-06', 333, 308, 88),
  ];

  static const double _hubX = 201;
  static const double _hubY = 222;
  static const double _phaseB = 3.6;
  static const double _rowStart = 1.3;
  static const double _rowStep = 1.15;
  static const double _rowFill = 0.85;
  static const double _rowDone = 0.9;
  static const int _rows = 5;
  static const double _loop = _phaseB + _rowStart + _rows * _rowStep + 2.8;
  static const double _headerCenterX = 64;
  static const double _headerCenterY = 63;
  static const double _headerLogo = 56;
  static const Curve _burst = Cubic(0.2, 1.25, 0.4, 1);
  static const Curve _fly = Cubic(0.3, 0.75, 0.2, 1);
  static const Curve _rise = Cubic(0.2, 0.85, 0.25, 1);
  static const Curve _fillCurve = Cubic(0.4, 0, 0.2, 1);

  @override
  Widget build(BuildContext context) {
    final modules = [
      'welcome_carousel.s2_mod1'.tr(),
      'welcome_carousel.s2_mod2'.tr(),
      'welcome_carousel.s2_mod3'.tr(),
      'welcome_carousel.s2_mod4'.tr(),
      'welcome_carousel.s2_mod5'.tr(),
    ];
    return WelcomeSceneFrame(
      child: WelcomeStage(
        active: active,
        builder: (context, clock) {
          final reduced = clock.reduced;
          final t = reduced ? 0.0 : clock.t % _loop;
          final epoch = reduced ? 0.0 : clock.t;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (!reduced)
                for (var i = 0; i < _badges.length; i++)
                  _badge(i, _badges[i], t, epoch),
              _ProgressCard(
                t: t,
                reduced: reduced,
                fadeOut: wProg(t, _loop - 0.4, 0.4),
                modules: modules,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _badge(int i, _Badge b, double t, double epoch) {
    final isViajero = b.code == 'CQ-05';
    final delay = i * 0.06;
    final burst = _burst.transform(wProg(t, delay, 0.8));
    final appear = burst.clamp(0.0, 1.0);

    // Phase B: the rest shrink away, Viajero heads for the card header.
    final leave = _fly.transform(wProg(t, _phaseB, 0.8));
    var dx = (1 - burst) * (_hubX - b.x);
    var dy = (1 - burst) * (_hubY - b.y);
    var scale = wLerp(0.15, 1, burst);
    var opacity = appear;
    if (t >= _phaseB) {
      if (isViajero) {
        dx += wLerp(0, _headerCenterX - b.x, leave);
        dy += wLerp(0, _headerCenterY - b.y, leave);
        scale *= wLerp(1, _headerLogo / b.size, leave);
        opacity *= 1 - Curves.ease.transform(wProg(t, _phaseB + 1.0, 0.3));
      } else {
        scale *= wLerp(1, 0.6, leave);
        opacity *= 1 - Curves.ease.transform(wProg(t, _phaseB, 0.45));
      }
    }
    if (opacity <= 0) return const SizedBox.shrink();

    final bob = wPingPong(epoch, 2 * (3.2 + (i % 5) * 0.45));
    final isGuide = b.code == 'GM-01';
    return Positioned(
      left: b.x - b.size / 2 + dx,
      top: b.y - b.size / 2 + dy,
      width: b.size,
      height: b.size,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Transform.translate(
            offset: Offset(0, -7 * bob),
            child: Transform.rotate(
              angle: 3 * bob * math.pi / 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isGuide) const _GoldGlow(),
                  welcomeClassBadge(b.code, b.size),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldGlow extends StatelessWidget {
  const _GoldGlow();

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.loginBrandGold.withValues(alpha: 0.6),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const SizedBox(width: _size, height: _size),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.t,
    required this.reduced,
    required this.fadeOut,
    required this.modules,
  });

  final double t;
  final bool reduced;
  final double fadeOut;
  final List<String> modules;

  static const double _padding = 16;

  double _rowStartAt(int i) =>
      WelcomeSceneClasses._phaseB +
      WelcomeSceneClasses._rowStart +
      i * WelcomeSceneClasses._rowStep;

  double _doneAt(int i) => _rowStartAt(i) + WelcomeSceneClasses._rowDone;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final cardStart = WelcomeSceneClasses._phaseB + 0.35;

    final rise = reduced
        ? 1.0
        : WelcomeSceneClasses._rise.transform(wProg(t, cardStart, 0.6));
    final opacity = reduced
        ? 1.0
        : Curves.ease.transform(wProg(t, cardStart, 0.5)) * (1 - fadeOut);

    var overall = 0.0;
    var steps = 0;
    if (reduced) {
      overall = 1;
      steps = WelcomeSceneClasses._rows;
    } else {
      for (var i = 0; i < WelcomeSceneClasses._rows; i++) {
        final p = wProg(t, _doneAt(i), 0.5);
        overall += Curves.ease.transform(p) / WelcomeSceneClasses._rows;
        if (t >= _doneAt(i)) steps++;
      }
    }
    final percent = (steps * 100 / WelcomeSceneClasses._rows).round();

    return Positioned(
      left: 20,
      right: 20,
      top: 18,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, 40 * (1 - rise)),
          child: Transform.scale(
            scale: wLerp(0.97, 1, rise),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.paper,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(color: c.border),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(_padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        welcomeClassBadge(
                          'CQ-05',
                          WelcomeSceneClasses._headerLogo,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'welcome_carousel.s2_overline'
                                    .tr()
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: c.textTertiary,
                                ),
                              ),
                              Text(
                                'welcome_carousel.s2_class'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: c.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: text.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.colorViajero,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Bar(
                      value: overall,
                      height: 8,
                      track: c.ink100,
                    ),
                    const SizedBox(height: 4),
                    for (var i = 0; i < WelcomeSceneClasses._rows; i++)
                      _ModuleRow(
                        index: i,
                        name: modules[i],
                        fill: reduced
                            ? 1
                            : WelcomeSceneClasses._fillCurve.transform(
                                wProg(
                                  t,
                                  _rowStartAt(i),
                                  WelcomeSceneClasses._rowFill,
                                ),
                              ),
                        done: reduced ? 1 : wProg(t, _doneAt(i), 0.3),
                        chip: reduced ? 1 : wProg(t, _doneAt(i), 0.35),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.height, required this.track});

  final double value;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: track),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(color: AppColors.colorViajero),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.index,
    required this.name,
    required this.fill,
    required this.done,
    required this.chip,
  });

  final int index;
  final String name;
  final double fill;
  final double done;
  final double chip;

  static const double _circle = 30;
  static const Curve _pop = Cubic(0.2, 0.9, 0.3, 1.4);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final tint = AppColors.colorViajero.withValues(alpha: 0.16);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borderLight)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(tint, AppColors.colorViajero, done),
              ),
              child: SizedBox(
                width: _circle,
                height: _circle,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Color.lerp(
                        AppColors.colorViajero,
                        c.onPrimary,
                        done,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Bar(value: fill, height: 6, track: c.ink100),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Opacity(
              opacity: Curves.ease.transform(chip.clamp(0.0, 1.0)),
              child: Transform.scale(
                scale: wLerp(0.6, 1, _pop.transform(chip)),
                child: const _ValidatedChip(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidatedChip extends StatelessWidget {
  const _ValidatedChip();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.successContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              size: 14,
              color: c.onSuccessContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'welcome_carousel.s2_validated'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w600,
                    color: c.onSuccessContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
