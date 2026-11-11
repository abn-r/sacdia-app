import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/sac_badge.dart';
import '../../domain/entities/service_credential.dart';

/// Estado de una constancia: Aprobada (éxito), En revisión (aviso) y Rechazada
/// (error). Lleva texto e ícono: el color nunca es lo único que lo dice.
class ServiceCredentialStatusPill extends StatelessWidget {
  const ServiceCredentialStatusPill({super.key, required this.status});

  final ServiceCredentialStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ServiceCredentialStatus.approved:
        return SacBadge.success(
          label: 'service_credentials.status.approved'.tr(),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case ServiceCredentialStatus.rejected:
        return SacBadge.error(
          label: 'service_credentials.status.rejected'.tr(),
          icon: HugeIcons.strokeRoundedCancelCircle,
        );
      case ServiceCredentialStatus.pendingReview:
      case ServiceCredentialStatus.unknown:
        return SacBadge.warning(
          label: 'service_credentials.status.pending'.tr(),
          icon: HugeIcons.strokeRoundedClock01,
        );
    }
  }
}
