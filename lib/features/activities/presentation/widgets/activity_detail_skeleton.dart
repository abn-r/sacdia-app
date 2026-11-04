import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

/// Skeleton that mirrors the ActivityDetailView layout structure.
///
/// Uses the shared [SacShimmer] around the content blocks (the app bar stays
/// outside so the back button is not tinted).
class ActivityDetailSkeleton extends StatelessWidget {
  const ActivityDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // AppBar placeholder (back button + title)
        SliverAppBar(
          automaticallyImplyLeading: false,
          leading: sacAutoBackButton(context),
          pinned: true,
          expandedHeight: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: context.sac.text,
        ),

        SliverToBoxAdapter(
          child: SacShimmer(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero block
                  SacSkeletonBox(height: 220, radius: AppTheme.radiusMD),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title line
                        SacSkeletonBox(width: 240, height: 22),
                        const SizedBox(height: 8),
                        // Type chip + platform badge — grouped left
                        Row(
                          children: [
                            SacSkeletonBox(
                                width: 68,
                                height: 22,
                                radius: AppTheme.radiusXS),
                            const SizedBox(width: 6),
                            SacSkeletonBox(
                                width: 80,
                                height: 22,
                                radius: AppTheme.radiusXS),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Meta line (countdown · section)
                        SacSkeletonBox(width: 180, height: 14),
                        const SizedBox(height: 16),

                        // Info strip (single card, fecha + hora)
                        SacSkeletonBox(height: 68, radius: AppTheme.radiusMD),
                        const SizedBox(height: 10),

                        // Location row
                        SacSkeletonBox(height: 56, radius: AppTheme.radiusMD),
                        const SizedBox(height: 24),

                        // Description header
                        SacSkeletonBox(width: 120, height: 18),
                        const SizedBox(height: 10),
                        // Description lines
                        SacSkeletonBox(height: 14),
                        const SizedBox(height: 6),
                        SacSkeletonBox(height: 14),
                        const SizedBox(height: 6),
                        SacSkeletonBox(width: 180, height: 14),
                        const SizedBox(height: 24),

                        // Attendees header
                        SacSkeletonBox(width: 140, height: 18),
                        const SizedBox(height: 12),
                        // Avatar row
                        Row(
                          children: List.generate(
                            5,
                            (i) => Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                              child: SacSkeletonBox(
                                  width: 36,
                                  height: 36,
                                  radius: AppTheme.radiusFull),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Creator footer
                        Row(
                          children: [
                            SacSkeletonBox(
                                width: 24,
                                height: 24,
                                radius: AppTheme.radiusFull),
                            const SizedBox(width: 8),
                            SacSkeletonBox(width: 160, height: 12),
                          ],
                        ),

                        // Bottom spacing for the fixed action bar
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
