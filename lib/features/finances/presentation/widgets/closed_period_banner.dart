import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/sac_notice.dart';

/// Aviso que aparece cuando el período está cerrado.
class ClosedPeriodBanner extends StatelessWidget {
  const ClosedPeriodBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SacNotice(
        tone: SacNoticeTone.warning,
        icon: HugeIcons.strokeRoundedLocked,
        text: 'finances.widgets.closed_period_banner'.tr(),
      ),
    );
  }
}
