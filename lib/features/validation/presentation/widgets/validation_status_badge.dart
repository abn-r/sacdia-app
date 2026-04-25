import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/validation.dart';

/// Badge compacto que muestra el estado de validación de una entidad.
class ValidationStatusBadge extends StatelessWidget {
  final ValidationStatus status;

  const ValidationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _configFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: config.icon,
            color: config.fg,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config.fg,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(ValidationStatus status) {
    switch (status) {
      case ValidationStatus.inProgress:
        return 'validation.status.inProgress'.tr();
      case ValidationStatus.pendingReview:
        return 'validation.status.pendingReview'.tr();
      case ValidationStatus.approved:
        return 'validation.status.approved'.tr();
      case ValidationStatus.rejected:
        return 'validation.status.rejected'.tr();
    }
  }

  _BadgeConfig _configFor(ValidationStatus status) {
    switch (status) {
      case ValidationStatus.approved:
        return _BadgeConfig(
          bg: AppColors.secondaryLight,
          fg: AppColors.secondaryDark,
          border: AppColors.secondary.withValues(alpha: 0.4),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case ValidationStatus.rejected:
        return _BadgeConfig(
          bg: AppColors.errorLight,
          fg: AppColors.errorDark,
          border: AppColors.error.withValues(alpha: 0.3),
          icon: HugeIcons.strokeRoundedCancel01,
        );
      case ValidationStatus.pendingReview:
        return _BadgeConfig(
          bg: AppColors.accentLight,
          fg: AppColors.accentDark,
          border: AppColors.accent.withValues(alpha: 0.4),
          icon: HugeIcons.strokeRoundedClock01,
        );
      case ValidationStatus.inProgress:
        return _BadgeConfig(
          bg: AppColors.statusInfoBgLight,
          fg: AppColors.statusInfoText,
          border: AppColors.statusInfoText.withValues(alpha: 0.2),
          icon: HugeIcons.strokeRoundedLoading01,
        );
    }
  }
}

class _BadgeConfig {
  final Color bg;
  final Color fg;
  final Color border;
  final dynamic icon;

  const _BadgeConfig({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });
}
