import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget para mostrar información del club
class ClubInfoCard extends StatelessWidget {
  final String? clubName;
  final String? clubType;
  final String? userRole;

  const ClubInfoCard({
    super.key,
    this.clubName,
    this.clubType,
    this.userRole,
  });

  /// Obtiene el color según el tipo de club
  Color _getClubColor(String? type) {
    if (type == null) return AppColors.sacBlue;

    switch (type.toLowerCase()) {
      case 'conquistadores':
        return AppColors.sacBlue;
      case 'aventureros':
        return AppColors.sacRed;
      case 'guías mayores':
      case 'guias mayores':
        return AppColors.colorGuiaMayor;
      default:
        return AppColors.sacBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubColor = _getClubColor(clubType);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: clubColor,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups,
                  color: clubColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mi Club',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clubName ?? 'Sin club asignado',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.sacBlack,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (clubType != null || userRole != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (clubType != null) ...[
                    Expanded(
                      child: _InfoItem(
                        icon: Icons.category,
                        label: 'Tipo',
                        value: clubType!,
                      ),
                    ),
                  ],
                  if (clubType != null && userRole != null)
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (userRole != null) ...[
                    Expanded(
                      child: _InfoItem(
                        icon: Icons.badge,
                        label: 'Rol',
                        value: userRole!,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.sacGreen,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.sacBlack,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
