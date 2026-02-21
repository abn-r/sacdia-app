import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/activity.dart';

/// Card de actividad - Estilo "Scout Vibrante"
///
/// Date badge indigo a la izquierda, título, hora+ubicación,
/// chip de tipo con color.
class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  String _getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return 'Reunión';
      case 'event':
        return 'Evento';
      case 'campout':
        return 'Campamento';
      case 'service':
        return 'Servicio';
      default:
        return 'Actividad';
    }
  }

  SacBadgeVariant _getTypeBadgeVariant(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return SacBadgeVariant.primary;
      case 'event':
        return SacBadgeVariant.accent;
      case 'campout':
        return SacBadgeVariant.secondary;
      default:
        return SacBadgeVariant.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SacCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(activity.date),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1,
                  ),
                ),
                Text(
                  DateFormat('MMM', 'es').format(activity.date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Activity info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(activity.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                    if (activity.location != null) ...[
                      Text(
                        ' · ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightTextTertiary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          activity.location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.lightTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                SacBadge(
                  label: _getTypeText(activity.type),
                  variant: _getTypeBadgeVariant(activity.type),
                ),
              ],
            ),
          ),

          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: AppColors.lightTextTertiary,
            size: 24,
          ),
        ],
      ),
    );
  }
}
