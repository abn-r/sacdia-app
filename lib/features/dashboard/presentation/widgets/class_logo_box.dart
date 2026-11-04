import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';

/// Caja con el logo de una clase progresiva: imagen de red cuando el backend la
/// entrega, si no el asset empaquetado y, sin asset, un icono de escuela.
///
/// Fondo del color de la clase al 12 %. [size] es el lado de la caja y
/// [padding] el aire alrededor del asset (60 con padding 8 deja un logo de 44).
class ClassLogoBox extends StatelessWidget {
  const ClassLogoBox({
    super.key,
    required this.className,
    this.imageUrl,
    this.size = 40,
    this.padding = 5,
    this.radius = AppTheme.radiusXS,
    this.iconSize = 20,
  });

  final String className;
  final String? imageUrl;
  final double size;
  final double padding;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final classColor = AppColors.classColor(className);
    final logoAsset = AppColors.classLogoAsset(className);
    final cachePx = (size * 3).round();

    Widget fallback() => logoAsset != null
        ? Padding(
            padding: EdgeInsets.all(padding),
            child: Image.asset(
              logoAsset,
              fit: BoxFit.contain,
              cacheWidth: cachePx,
              cacheHeight: cachePx,
            ),
          )
        : Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSchool,
              color: classColor,
              size: iconSize,
            ),
          );

    final url = imageUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: classColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: url != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: SacNetworkImage(
                imageUrl: url,
                memCacheWidth: cachePx,
                memCacheHeight: cachePx,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => fallback(),
              ),
            )
          : fallback(),
    );
  }
}
