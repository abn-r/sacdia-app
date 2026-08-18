import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Marca SACDIA a partir de `logo-sacdia.png`.
///
/// El asset es un icono cuadrado (fondo azul + carpeta dorada). Se recorta
/// con radio tipo squircle iOS y sombra suave para sentarse sobre canvas blanco.
class SacBrandMark extends StatelessWidget {
  static const String assetPath = 'assets/img/logo-sacdia.png';

  /// Radio iOS (~22.37% del lado) para corners de icono.
  static const double squircleRatio = 0.2237;

  final double size;
  final bool elevated;
  final String? semanticLabel;

  const SacBrandMark({
    super.key,
    required this.size,
    this.elevated = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * squircleRatio);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * dpr).round().clamp(64, 1024);

    final image = ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.high,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      ),
    );

    // Isolate clip+bitmap from parent FadeTransition. Impeller cannot push
    // inherited opacity into ClipRRect/Image contents.
    final mark = elevated
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: context.sac.shadow,
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: image,
          )
        : image;

    return RepaintBoundary(child: mark);
  }
}

/// Acento dorado del icono — separa marca de copy.
class SacBrandHairline extends StatelessWidget {
  const SacBrandHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 28,
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.loginBrandGold,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
