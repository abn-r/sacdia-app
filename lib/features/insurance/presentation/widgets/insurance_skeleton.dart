import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sac_skeleton.dart';
import '../../../../core/widgets/sac_top_bar.dart';

/// Skeleton with the real shape of the screen: summary box and a
/// group of rows.
class InsuranceSkeleton extends StatelessWidget {
  const InsuranceSkeleton({super.key, this.rows = 6});

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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SacSkeletonBox(width: 120, height: 12),
                  SizedBox(height: 10),
                  SacSkeletonBox(width: 160, height: 30),
                  SizedBox(height: 14),
                  SacSkeletonBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SacSkeletonBox(width: 90, height: 10),
            const SizedBox(height: 12),
            for (var i = 0; i < rows; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SacSkeletonBox(
                      width: 36,
                      height: 36,
                      radius: AppTheme.radiusFull,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SacSkeletonBox(width: 150, height: 12),
                          SizedBox(height: 8),
                          SacSkeletonBox(width: 90, height: 10),
                        ],
                      ),
                    ),
                    SacSkeletonBox(
                      width: 64,
                      height: 20,
                      radius: AppTheme.radiusFull,
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
