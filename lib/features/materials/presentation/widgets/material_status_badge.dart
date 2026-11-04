import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/sac_badge.dart';
import '../../domain/entities/material_status.dart';

/// Badge visual para el estado de una orden de materiales.
///
/// Usa [SacBadge] (tokens semánticos, seguro en modo oscuro) con icono:
/// - en_revision → neutral
/// - aprobada    → warning
/// - pagada / entregada → success
/// - cancelada   → error
class MaterialStatusBadge extends StatelessWidget {
  final MaterialStatus status;

  const MaterialStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MaterialStatus.enRevision:
        return SacBadge(
          label: 'materials.status.in_review'.tr(),
          icon: HugeIcons.strokeRoundedClock01,
          variant: SacBadgeVariant.neutral,
        );
      case MaterialStatus.aprobada:
        return SacBadge.warning(
          label: 'materials.status.approved'.tr(),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case MaterialStatus.pagada:
        return SacBadge.success(
          label: 'materials.status.paid'.tr(),
          icon: HugeIcons.strokeRoundedMoney01,
        );
      case MaterialStatus.entregada:
        return SacBadge.success(
          label: 'materials.status.delivered'.tr(),
          icon: HugeIcons.strokeRoundedPackage,
        );
      case MaterialStatus.cancelada:
        return SacBadge.error(
          label: 'materials.status.cancelled'.tr(),
          icon: HugeIcons.strokeRoundedCancelCircle,
        );
    }
  }
}
