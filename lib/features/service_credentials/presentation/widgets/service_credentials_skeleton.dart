import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/sac_skeleton.dart';

/// Placeholder de las listas de constancias mientras cargan: un encabezado de
/// grupo y filas como las reales. Un solo shimmer envuelve todo.
class ServiceCredentialsSkeleton extends StatelessWidget {
  const ServiceCredentialsSkeleton({super.key, this.rowCount = 4});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'service_credentials.loading'.tr(),
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: SacShimmer(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  widthFactor: 0.6,
                  child: SacSkeletonBox(height: 13),
                ),
                SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: 0.4,
                  child: SacSkeletonBox(height: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
