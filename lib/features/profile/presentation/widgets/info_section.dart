import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';

/// Sección de información estilo iOS grouped list.
/// Sin Card — agrupación de filas con Divider fino, header en uppercase.
class InfoSection extends StatelessWidget {
  final String title;
  final List<InfoItem> items;

  const InfoSection({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header estilo iOS section — uppercase, pequeño, gris
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.sac.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        // Contenedor de filas agrupadas — fondo blanco, bordes redondeados
        Container(
          decoration: BoxDecoration(
            color: context.sac.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.sac.border,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _InfoItemWidget(
                    item: items[i],
                    isFirst: i == 0,
                    isLast: i == items.length - 1),
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    // Divider alineado con el contenido (indentado)
                    indent: 56,
                    endIndent: 0,
                    color: context.sac.borderLight,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Modelo para un elemento de información
class InfoItem {
  final dynamic icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const InfoItem({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });
}

class _InfoItemWidget extends StatelessWidget {
  final InfoItem item;
  final bool isFirst;
  final bool isLast;

  const _InfoItemWidget({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(14) : Radius.zero,
        bottom: isLast ? const Radius.circular(14) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            // ícono en contenedor neutro — estilo iOS SF Symbol container
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.sac.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: item.icon is IconData
                  ? Icon(
                      item.icon as IconData,
                      color: context.sac.textSecondary,
                      size: 17,
                    )
                  : HugeIcon(
                      icon: item.icon,
                      color: context.sac.textSecondary,
                      size: 17,
                    ),
            ),
            const SizedBox(width: 12),
            // Label + Valor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: context.sac.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.value ?? 'No especificado',
                    style: item.value != null
                        ? TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.sac.text,
                          )
                        : TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.sac.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (item.onTap != null)
              Icon(
                Icons.chevron_right,
                color: context.sac.textTertiary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
