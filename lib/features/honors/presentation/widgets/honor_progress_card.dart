import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/user_honor.dart';

/// Card de progreso de honor del usuario - Estilo "Scout Vibrante"
///
/// SacCard con status badge, nombre, fechas.
/// Completados: badge dorado (amber). En progreso: badge indigo.
class HonorProgressCard extends StatelessWidget {
  final UserHonor userHonor;
  final String honorName;
  final VoidCallback onTap;

  const HonorProgressCard({
    super.key,
    required this.userHonor,
    required this.honorName,
    required this.onTap,
  });

  SacBadgeVariant get _badgeVariant {
    switch (userHonor.status.toLowerCase()) {
      case 'completed':
        return SacBadgeVariant.accent; // amber/gold
      case 'in_progress':
        return SacBadgeVariant.primary; // indigo
      default:
        return SacBadgeVariant.neutral;
    }
  }

  String get _statusText {
    switch (userHonor.status.toLowerCase()) {
      case 'completed':
        return 'Completada';
      case 'in_progress':
        return 'En progreso';
      default:
        return 'Pendiente';
    }
  }

  dynamic get _statusIcon {
    switch (userHonor.status.toLowerCase()) {
      case 'completed':
        return HugeIcons.strokeRoundedAward03;
      case 'in_progress':
        return HugeIcons.strokeRoundedClock01;
      default:
        return HugeIcons.strokeRoundedClock02;
    }
  }

  Color get _iconColor {
    switch (userHonor.status.toLowerCase()) {
      case 'completed':
        return AppColors.accent;
      case 'in_progress':
        return AppColors.primary;
      default:
        return AppColors.lightTextTertiary;
    }
  }

  Color get _iconBgColor {
    switch (userHonor.status.toLowerCase()) {
      case 'completed':
        return AppColors.accentLight;
      case 'in_progress':
        return AppColors.primaryLight;
      default:
        return AppColors.lightSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SacCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: buildIcon(_statusIcon, size: 22, color: _iconColor),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  honorName,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SacBadge(
                      label: _statusText,
                      variant: _badgeVariant,
                    ),
                    const SizedBox(width: 8),
                    if (userHonor.completionDate != null)
                      Text(
                        DateFormat('dd/MM/yyyy')
                            .format(userHonor.completionDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightTextSecondary,
                        ),
                      )
                    else if (userHonor.startDate != null)
                      Text(
                        'Desde ${DateFormat('dd/MM/yyyy').format(userHonor.startDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
