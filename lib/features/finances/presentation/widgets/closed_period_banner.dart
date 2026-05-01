import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';

/// Banner que aparece cuando el período está cerrado.
class ClosedPeriodBanner extends StatelessWidget {
  const ClosedPeriodBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedLocked,
            size: 18,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'finances.widgets.closed_period_banner'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.accentDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
