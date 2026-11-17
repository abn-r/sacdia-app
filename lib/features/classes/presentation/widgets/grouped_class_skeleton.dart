import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sac_skeleton.dart';
import '../../../../core/widgets/sac_top_bar.dart';

/// Loading placeholder shared by the grouped-class screens: the summary box
/// and a card of rows. One [SacShimmer] over [SacSkeletonBox]es.
class GroupedClassSkeleton extends StatelessWidget {
  const GroupedClassSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(
            context,
            const EdgeInsets.fromLTRB(20, 8, 20, 32),
          ),
          children: [
            const SacSkeletonBox(height: 120, radius: AppTheme.radiusLG),
            const SizedBox(height: 28),
            const SacSkeletonBox(width: 80, height: 10),
            const SizedBox(height: 12),
            for (var i = 0; i < rows; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SacSkeletonBox(width: 32, height: 32, radius: 16),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SacSkeletonBox(width: 160, height: 14),
                          SizedBox(height: 6),
                          SacSkeletonBox(width: 110, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
