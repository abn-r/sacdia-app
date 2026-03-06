import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/activity.dart';

/// Card de actividad - Estilo moderno inspirado en task management
///
/// Chip de tipo arriba, título prominente, metadata (fecha/hora/lugar)
/// con íconos, botón de flecha circular a la derecha.
class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  String _getTypeText(int type, [String? typeName]) {
    final normalizedName = typeName?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    switch (type) {
      case 1:
        return 'Regular';
      case 2:
        return 'Especial';
      case 3:
        return 'Camporee';
      default:
        return 'Actividad';
    }
  }

  SacBadgeVariant _getTypeBadgeVariant(int type) {
    switch (type) {
      case 1:
        return SacBadgeVariant.primary;
      case 2:
        return SacBadgeVariant.accent;
      case 3:
        return SacBadgeVariant.secondary;
      default:
        return SacBadgeVariant.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      animate: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: type badge + arrow button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SacBadge(
                label: _getTypeText(
                  activity.activityType,
                  activity.activityTypeName,
                ),
                variant: _getTypeBadgeVariant(activity.activityType),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            activity.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Metadata row
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (activity.createdAt != null)
                _MetaItem(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  label: DateFormat('d MMM yyyy', 'es')
                      .format(activity.createdAt!),
                  c: c,
                ),
              if (activity.activityTime != null)
                _MetaItem(
                  icon: HugeIcons.strokeRoundedClock01,
                  label: activity.activityTime!,
                  c: c,
                ),
              if (activity.activityPlace.isNotEmpty)
                _MetaItem(
                  icon: HugeIcons.strokeRoundedLocation01,
                  label: activity.activityPlace,
                  c: c,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  // ignore: prefer_typing_uninitialized_variables
  final dynamic icon;
  final String label;
  final SacColors c;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 13, color: c.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: c.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
