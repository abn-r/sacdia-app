import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Wash azul del icono SACDIA — cielo de login, registro y recuperación.
/// Muere al 42% para dejar canvas blanco al formulario.
/// El carrusel de bienvenida ya no lo usa: el arte ilustrado es el cielo.
class AuthSkyWash extends StatelessWidget {
  const AuthSkyWash({super.key, this.fadeEnd = 0.42});

  /// Stop donde el azul llega a alpha 0. 0–1 del alto.
  final double fadeEnd;

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
              stops: [0.0, fadeEnd],
            ),
          ),
        ),
      ),
    );
  }
}
