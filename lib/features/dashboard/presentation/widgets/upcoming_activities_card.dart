import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/dashboard_summary.dart';

/// Card de próximas actividades - Estilo "Scout Vibrante"
///
/// Lista compacta con date badges indigo, "Ver todas" link.
class UpcomingActivitiesCard extends StatelessWidget {
  final List<UpcomingActivity> activities;
  final VoidCallback? onViewAll;

  const UpcomingActivitiesCard({
    super.key,
    required this.activities,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return SacCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Próximas Actividades',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (activities.isNotEmpty && onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    'Ver todas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar04,
                      size: 40,
                      color: context.sac.textTertiary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay actividades programadas',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.sac.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...activities.asMap().entries.map((entry) {
              final isLast = entry.key == activities.length - 1;
              return _ActivityRow(
                activity: entry.value,
                showDivider: !isLast,
              );
            }),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final UpcomingActivity activity;
  final bool showDivider;

  const _ActivityRow({
    required this.activity,
    this.showDivider = true,
  });

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date.toLocal());
  }

  String _formatRelativeDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = local.difference(now);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Mañana';
    if (diff.inDays < 7) return DateFormat('EEEE', 'es').format(local);
    return DateFormat('dd MMM', 'es').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Date badge
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd').format(activity.date.toLocal()),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        height: 1,
                      ),
                    ),
                    Text(
                      DateFormat('MMM', 'es')
                          .format(activity.date.toLocal())
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Activity info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${_formatRelativeDate(activity.date)} · ${_formatTime(activity.date)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.sac.textSecondary,
                          ),
                        ),
                        if (activity.location != null) ...[
                          Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.sac.textTertiary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              activity.location!,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.sac.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: context.sac.borderLight,
            indent: 60,
          ),
      ],
    );
  }
}
