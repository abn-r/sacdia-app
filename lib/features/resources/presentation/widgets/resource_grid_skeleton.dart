import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'resource_card.dart';

/// Loading placeholder with the shape of the library grid: cover, title and
/// detail line per tile, so nothing jumps when the data arrives.
class ResourceGridSkeleton extends StatelessWidget {
  const ResourceGridSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'resources.loading'.tr(),
      container: true,
      child: SacShimmer(
        child: GridView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.horizontalPadding(context),
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: resourceGridDelegate,
          itemCount: itemCount,
          itemBuilder: (_, __) => const ResourceCardSkeleton(),
        ),
      ),
    );
  }
}

/// One tile of [ResourceGridSkeleton], laid out like [ResourceCard].
class ResourceCardSkeleton extends StatelessWidget {
  const ResourceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SacSkeletonBox(height: double.infinity, radius: 0)),
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SacSkeletonBox(height: 12),
                SizedBox(height: 7),
                SacSkeletonBox(width: 70, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
