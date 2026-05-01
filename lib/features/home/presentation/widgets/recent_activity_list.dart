import 'package:easy_localization/easy_localization.dart';
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
    // Replaced ListView.separated(shrinkWrap: true) with Column to avoid
    // O(n²) layout inside the parent SingleChildScrollView. Item count is
    // small (upcoming activities from the dashboard — typically < 10).
    return SacCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int index = 0; index < activities.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                indent: 60,
                color: context.sac.border,
              ),
            Padding(
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
                          activities[index],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plural('home.recent_activity.hours_ago', index + 1),
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
            ),
          ],
        ],
      ),
    );
  }
}
