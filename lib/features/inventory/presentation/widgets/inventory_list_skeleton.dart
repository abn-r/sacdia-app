import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_skeleton.dart';
import 'inventory_item_card.dart';

/// Loading placeholder shaped like the grouped list: two groups, each an
/// eyebrow and a card of rows with a 46px image and two lines.
class InventoryListSkeleton extends StatelessWidget {
  const InventoryListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SacShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SkeletonGroup(rows: 3),
          _SkeletonGroup(rows: 2),
        ],
      ),
    );
  }
}

class _SkeletonGroup extends StatelessWidget {
  final int rows;

  const _SkeletonGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: SacSkeletonBox(width: 96, height: 10),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.divider),
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        SacSkeletonBox(
                          width: InventoryItemCard.imageSize,
                          height: InventoryItemCard.imageSize,
                          radius: AppTheme.radiusSM,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SacSkeletonBox(height: 14),
                              SizedBox(height: 8),
                              SacSkeletonBox(width: 150, height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
