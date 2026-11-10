import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

/// Placeholder of the candidates list while it loads: a group header and rows
/// that mimic `RoleCandidateRow`. One shimmer wraps everything.
class RoleCandidatesSkeleton extends StatelessWidget {
  const RoleCandidatesSkeleton({super.key, this.rowCount = 5});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'members.role_candidates.loading'.tr(),
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: SacShimmer(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SacSkeletonBox(width: 140, height: 12),
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < rowCount; i++) const _RowSkeleton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SacSkeletonBox(width: 40, height: 40, radius: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.55,
                  child: SacSkeletonBox(height: 13),
                ),
                SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: 0.4,
                  child: SacSkeletonBox(height: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
