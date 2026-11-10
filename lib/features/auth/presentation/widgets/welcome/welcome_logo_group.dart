import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/auth/presentation/theme/auth_tokens.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/sac_brand_mark.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/welcome/welcome_common.dart';

/// The SACDIA logo with its glow, an optional diagonal shine and (scene 6) the
/// shared Hero that flies into the login screen.
///
/// Always laid out at [logoSize] and scaled with a Transform, so the Hero flight
/// starts from whatever size the scene is showing.
class WelcomeLogoGroup extends StatelessWidget {
  const WelcomeLogoGroup({
    super.key,
    required this.center,
    required this.scale,
    this.opacity = 1,
    this.glowFactor = 1.7,
    this.glowScale = 1,
    this.glowOpacity = 1,
    this.shine,
    this.hero = false,
  });

  /// Where the middle of the logo sits in the 402x440 design box.
  final Offset center;
  final double scale;
  final double opacity;

  /// Glow diameter as a multiple of the logo size.
  final double glowFactor;
  final double glowScale;
  final double glowOpacity;

  /// Centre of the shine band in logo widths, or null for no shine.
  final double? shine;
  final bool hero;

  static const double logoSize = 173;

  @override
  Widget build(BuildContext context) {
    final glow = logoSize * glowFactor;
    final mark = SacBrandMark(size: logoSize);
    return Positioned(
      left: center.dx - logoSize / 2,
      top: center.dy - logoSize / 2,
      width: logoSize,
      height: logoSize,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: (logoSize - glow) / 2,
                top: (logoSize - glow) / 2,
                child: Opacity(
                  opacity: glowOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: glowScale,
                    child: WelcomeGlow(diameter: glow),
                  ),
                ),
              ),
              Positioned.fill(
                child: hero
                    ? Hero(tag: AuthTokens.brandMarkHeroTag, child: mark)
                    : mark,
              ),
              if (shine != null) Positioned.fill(child: _Shine(center: shine!)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shine extends StatelessWidget {
  const _Shine({required this.center});

  final double center;

  static const double _halfWidth = 0.39;

  @override
  Widget build(BuildContext context) {
    final white = context.sac.onPrimary;
    final x = 2 * center - 1;
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          SacBrandMark.squircleRatio * WelcomeLogoGroup.logoSize,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(x - _halfWidth * 2, -0.5),
              end: Alignment(x + _halfWidth * 2, 0.5),
              colors: [
                white.withValues(alpha: 0),
                white.withValues(alpha: 0.75),
                white.withValues(alpha: 0),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Positions and looks of the scene-1 twinkles, relative to the logo centre.
class WelcomeSparkSpec {
  const WelcomeSparkSpec(this.dx, this.dy, this.kind, this.delay, this.size);

  final double dx;
  final double dy;
  final WelcomeSparkTone kind;
  final double delay;
  final double size;

  Color color() => switch (kind) {
        WelcomeSparkTone.gold => AppColors.loginBrandGold,
        WelcomeSparkTone.blue => AppColors.loginBrandBlue,
        WelcomeSparkTone.sky => AppColors.info,
      };
}

enum WelcomeSparkTone { gold, blue, sky }
