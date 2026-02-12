import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget para mostrar estadísticas rápidas de especialidades
class QuickStatsCard extends StatelessWidget {
  final int honorsCompleted;
  final int honorsInProgress;

  const QuickStatsCard({
    super.key,
    required this.honorsCompleted,
    required this.honorsInProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sacYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.military_tech,
                    color: AppColors.sacYellow,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Mis Especialidades',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sacBlack,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    value: honorsCompleted.toString(),
                    label: 'Completadas',
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.pending,
                    color: AppColors.info,
                    value: honorsInProgress.toString(),
                    label: 'En progreso',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
