import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';

/// Fila de configuración estilo iOS Settings.app:
/// - Ícono en contenedor cuadrado redondeado con color propio
/// - Título + subtítulo opcionales
/// - Chevron derecho si tiene onTap
class SettingTile extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  // Color de fondo del contenedor del ícono (opcional)
  final Color? iconBackgroundColor;

  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.iconBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final effectiveIconColor = iconColor ?? c.textSecondary;
    // Fondo: si hay color de ícono definido (p.ej. error), usar versión light; si no, neutro
    final effectiveBg = iconBackgroundColor ??
        (iconColor != null
            ? iconColor!.withValues(alpha: 0.12)
            : c.surfaceVariant);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            // Contenedor del ícono — estilo iOS app icon
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: effectiveBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: effectiveIconColor,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Título + subtítulo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      // Si el ícono es de error, el texto también va en ese tono
                      color: iconColor == AppColors.error
                          ? AppColors.error
                          : c.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Trailing o chevron
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: c.textTertiary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
