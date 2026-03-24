import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

/// Lista de actividades recientes - Estilo "Scout Vibrante"
class RecentActivityList extends StatelessWidget {
  final List<String> activities;

  const RecentActivityList({
    super.key,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return SacCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: activities.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 60,
          color: context.sac.border,
        ),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedClock05,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hace ${index + 1} ${index == 0 ? 'hora' : 'horas'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.sac.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
