import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_common.dart';

/// Where a card sits in the deck: offset, tilt (degrees), scale and opacity.
class _Pose {
  const _Pose(this.dx, this.dy, this.turn, this.scale, this.opacity);

  final double dx;
  final double dy;
  final double turn;
  final double scale;
  final double opacity;

  static _Pose lerp(_Pose a, _Pose b, double p) => _Pose(
        wLerp(a.dx, b.dx, p),
        wLerp(a.dy, b.dy, p),
        wLerp(a.turn, b.turn, p),
        wLerp(a.scale, b.scale, p),
        wLerp(a.opacity, b.opacity, p),
      );
}

/// Scene 4: 22 big, readable cards. A new one is dealt from below onto the
/// front of the deck every ~1.5s; the previous three fan out behind it.
class WelcomeSceneDeck extends StatelessWidget {
  const WelcomeSceneDeck({super.key, required this.active});

  final bool active;

  static const List<HugeIconData> _icons = [
    HugeIcons.strokeRoundedCheckmarkCircle02,
    HugeIcons.strokeRoundedGraduationScroll,
    HugeIcons.strokeRoundedMoneyBag02,
    HugeIcons.strokeRoundedQrCode,
    HugeIcons.strokeRoundedFire,
    HugeIcons.strokeRoundedCertificate01,
    HugeIcons.strokeRoundedFile01,
    HugeIcons.strokeRoundedCalendar03,
    HugeIcons.strokeRoundedPackage,
    HugeIcons.strokeRoundedChartBarLine,
    HugeIcons.strokeRoundedShield01,
    HugeIcons.strokeRoundedUserMultiple,
    HugeIcons.strokeRoundedUserGroup,
    HugeIcons.strokeRoundedGraduationScroll,
    HugeIcons.strokeRoundedChartLineData01,
    HugeIcons.strokeRoundedInvoice01,
    HugeIcons.strokeRoundedNotification01,
    HugeIcons.strokeRoundedTask01,
    HugeIcons.strokeRoundedMedal01,
    HugeIcons.strokeRoundedHome01,
    HugeIcons.strokeRoundedFile01,
    HugeIcons.strokeRoundedCalendar03,
  ];

  static const int _count = 22;
  static const double _cardWidth = 262;
  static const double _cardHeight = 160;
  static const double _centerX = 201;
  static const double _centerY = 250;
  static const double _transition = 0.7;
  static const Curve _settle = Cubic(0.2, 0.85, 0.25, 1);

  static const _Pose _below = _Pose(0, 330, 9, 1, 0);
  static const List<_Pose> _poses = [
    _Pose(0, 0, 0, 1, 1),
    _Pose(-30, -26, -7, 0.93, 1),
    _Pose(30, -46, 6, 0.86, 0.95),
    _Pose(0, -64, 0, 0.8, 0.5),
  ];
  static const _Pose _gone = _Pose(0, -80, 0, 0.74, 0);

  /// Moment the n-th card is dealt: four quick ones, then every 1.5s.
  static double _dealTime(int n) => n < 4 ? n * 0.3 : 0.95 + 1.5 * (n - 3);

  /// How many cards have been dealt at time [t].
  static int _dealt(double t) {
    if (t < 0.95) return math.min(4, (t / 0.3).floor() + 1);
    return 4 + ((t - 0.95) / 1.5).floor();
  }

  static _Pose _target(int rank) => rank < 4 ? _poses[rank] : _gone;

  /// Pose of the card dealt as number [n] at time [t]. Every deal retargets
  /// the card from wherever it currently is, like a CSS transition would.
  static _Pose _poseAt(int n, double t, int dealt) {
    var pose = _below;
    for (var j = n; j < dealt; j++) {
      final start = _dealTime(j);
      final end = j + 1 < dealt ? _dealTime(j + 1) : t;
      final p = _settle.transform(wProg(end, start, _transition));
      pose = _Pose.lerp(pose, _target(j - n), p);
    }
    return pose;
  }

  @override
  Widget build(BuildContext context) {
    return WelcomeSceneFrame(
      child: WelcomeStage(
        active: active,
        builder: (context, clock) {
          // Reduced motion: the deck as it looks once four cards are dealt.
          final t = clock.reduced ? 2.4 : clock.t;
          final dealt = _dealt(t);
          final from = math.max(0, dealt - 5);
          final theme = Theme.of(context).textTheme;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var n = from; n < dealt; n++)
                _card(context, n, _poseAt(n, t, dealt)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Text(
                  'welcome_carousel.s4_more'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.sac.textTertiary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, int n, _Pose pose) {
    if (pose.opacity <= 0) return const SizedBox.shrink();
    final index = n % _count;
    return Positioned(
      left: _centerX - _cardWidth / 2 + pose.dx,
      top: _centerY - _cardHeight / 2 + pose.dy,
      width: _cardWidth,
      height: _cardHeight,
      child: Opacity(
        opacity: pose.opacity,
        child: Transform.rotate(
          angle: pose.turn * math.pi / 180,
          child: Transform.scale(
            scale: pose.scale,
            child: _DeckCard(
              icon: _icons[index],
              title:
                  'welcome_carousel.s4_c${(index + 1).toString().padLeft(2, '0')}_t'
                      .tr(),
              body:
                  'welcome_carousel.s4_c${(index + 1).toString().padLeft(2, '0')}_d'
                      .tr(),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final HugeIconData icon;
  final String title;
  final String body;

  static const double _iconBox = 46;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    return RepaintBoundary(
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
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.infoContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: SizedBox(
                  width: _iconBox,
                  height: _iconBox,
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      size: 24,
                      color: AppColors.loginBrandBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium?.copyWith(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.45,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
