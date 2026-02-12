import 'package:flutter/material.dart';

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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.sacBlack,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _InfoItemWidget(item: item)),
          ],
        ),
      ),
    );
  }
}

/// Modelo para un elemento de información
class InfoItem {
  final IconData icon;
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sacGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.icon,
                color: AppColors.sacGreen,
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.value ?? 'No especificado',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: item.value != null
                          ? AppColors.sacBlack
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (item.onTap != null)
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }
}
