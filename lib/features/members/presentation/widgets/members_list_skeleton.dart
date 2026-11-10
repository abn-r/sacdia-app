import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

/// Placeholder de la lista de miembros mientras carga: un encabezado de grupo
/// y filas que imitan a `MemberCard`. Un solo shimmer envuelve todo.
class MembersListSkeleton extends StatelessWidget {
  const MembersListSkeleton({super.key, this.rowCount = 6});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);

    return Semantics(
      label: 'members.view.loading'.tr(),
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: SacShimmer(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SacSkeletonBox(width: 110, height: 12),
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < rowCount; i++) const _MemberRowSkeleton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberRowSkeleton extends StatelessWidget {
  const _MemberRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SacSkeletonBox(width: 38, height: 38, radius: 19),
            SizedBox(width: 10),
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
                    widthFactor: 0.38,
                    child: SacSkeletonBox(height: 10),
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
