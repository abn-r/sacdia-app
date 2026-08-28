import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Crédito de estudio: icono + «by Zarza Roja».
///
/// PNG vía [Image.opacity] si hay animación — Impeller no acepta
/// FadeTransition anidado sobre el bitmap.
class ZarzaRojaCredit extends StatelessWidget {
  static const assetPath = 'assets/img/logo-zarza-roja.png';

  const ZarzaRojaCredit({super.key, this.opacity});

  final Animation<double>? opacity;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.sac.textTertiary,
          fontWeight: FontWeight.w500,
        );
    final iconSize = 45.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (iconSize * dpr).round().clamp(48, 512);

    final mark = RepaintBoundary(
      child: Image.asset(
        assetPath,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        excludeFromSemantics: true,
        opacity: opacity,
      ),
    );

    final label = Text('by Zarza Roja', style: style);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 6),
        if (opacity == null)
          label
        else
          FadeTransition(opacity: opacity!, child: label),
      ],
    );
  }
}
