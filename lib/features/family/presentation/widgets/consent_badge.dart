import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/sac_badge.dart';
import '../../domain/entities/dependent.dart';

/// Insignia del consentimiento del tutor: pendiente o verificado.
class ConsentBadge extends StatelessWidget {
  const ConsentBadge({super.key, required this.status});

  final GuardianConsentStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      GuardianConsentStatus.verified => SacBadge.success(
          label: 'family.consent.verified'.tr(),
          icon: HugeIcons.strokeRoundedCheckmarkBadge01,
        ),
      GuardianConsentStatus.pending => SacBadge.warning(
          label: 'family.consent.pending'.tr(),
          icon: HugeIcons.strokeRoundedClock01,
        ),
    };
  }
}
