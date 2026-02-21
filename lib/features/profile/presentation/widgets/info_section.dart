import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget para mostrar una sección de información del perfil
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
    return SacCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _InfoItemWidget(item: item)),
        ],
      ),
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

  const _InfoItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Value — overflow guard for long strings
                  Text(
                    item.value ?? 'No especificado',
                    style: item.value != null
                        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.lightText,
                            )
                        : Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.lightTextTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (item.onTap != null)
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.lightTextTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
