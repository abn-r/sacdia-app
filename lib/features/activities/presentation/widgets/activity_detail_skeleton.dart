import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

import 'activity_date_tile.dart';
import 'activity_map_card.dart';

/// Skeleton that mirrors the ActivityDetailView layout: date tile + name +
/// chip, map card, state panel, grouped DETAILS block, description and
/// attendance. The top bar belongs to the screen, so it is not drawn here.
class ActivityDetailSkeleton extends StatelessWidget {
  const ActivityDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: SacShimmer(
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date tile + name + type chip
                Row(
                  children: [
                    SacSkeletonBox(
                      width: ActivityDateTile.size,
                      height: ActivityDateTile.size,
                      radius: AppTheme.radiusMD,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SacSkeletonBox(height: 20),
                          const SizedBox(height: 6),
                          SacSkeletonBox(
                            width: 96,
                            height: 22,
                            radius: AppTheme.radiusLG,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Map card + place line
                SacSkeletonBox(
                  height: ActivityMapCard.mapHeight,
                  radius: AppTheme.radiusMD,
                ),
                const SizedBox(height: 8),
                SacSkeletonBox(width: 200, height: 14),
                const SizedBox(height: 16),

                // State panel
                SacSkeletonBox(height: 76, radius: AppTheme.radiusMD),
                const SizedBox(height: 24),

                // DETAILS eyebrow + grouped rows
                SacSkeletonBox(width: 64, height: 12),
                const SizedBox(height: 8),
                SacSkeletonBox(height: 112, radius: AppTheme.radiusMD),
                const SizedBox(height: 24),

                // Description
                SacSkeletonBox(width: 90, height: 12),
                const SizedBox(height: 8),
                SacSkeletonBox(height: 14),
                const SizedBox(height: 6),
                SacSkeletonBox(width: 220, height: 14),
                const SizedBox(height: 24),

                // Attendance
                SacSkeletonBox(width: 80, height: 12),
                const SizedBox(height: 8),
                SacSkeletonBox(height: 56, radius: AppTheme.radiusMD),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
