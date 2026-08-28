import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Wash azul del icono SACDIA — cielo de pantallas de auth.
///
/// 65% arriba, se desvanece a 0 hacia el formulario. Sin interacción.
class AuthSkyWash extends StatelessWidget {
  const AuthSkyWash({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.loginBrandBlue.withValues(alpha: 0.65),
                AppColors.loginBrandBlue.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.42],
            ),
          ),
        ),
      ),
    );
  }
}
