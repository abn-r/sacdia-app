import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/features/auth/presentation/theme/auth_tokens.dart';

/// Brand-blue sky at the top of the auth screens. It follows the theme:
/// in dark mode the wash stays low (see [AuthTokens.skyAlpha]).
class AuthSkyWash extends StatelessWidget {
  const AuthSkyWash({
    super.key,
    this.strength = AuthSkyStrength.regular,
    this.fadeEnd = AuthTokens.skyFadeEnd,
  });

  final AuthSkyStrength strength;
  final double fadeEnd;

  @override
  Widget build(BuildContext context) {
    final alpha = AuthTokens.skyAlpha(strength, Theme.of(context).brightness);
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.loginBrandBlue.withValues(alpha: alpha),
                AppColors.loginBrandBlue.withValues(alpha: 0),
              ],
              stops: [0.0, fadeEnd],
            ),
          ),
        ),
      ),
    );
  }
}
