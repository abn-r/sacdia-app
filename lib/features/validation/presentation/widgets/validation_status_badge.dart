import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/validation.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Badge compacto que muestra el estado de validación de una entidad.
class ValidationStatusBadge extends StatelessWidget {
  final ValidationStatus status;

  const ValidationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _configFor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
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
              fontSize: SacFontSize.labelSmall,
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

  _BadgeConfig _configFor(BuildContext context, ValidationStatus status) {
    final c = context.sac;
    switch (status) {
      case ValidationStatus.approved:
        return _BadgeConfig(
          bg: c.successContainer,
          fg: c.onSuccessContainer,
          border: c.success.withValues(alpha: 0.4),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case ValidationStatus.rejected:
        return _BadgeConfig(
          bg: c.errorContainer,
          fg: c.onErrorContainer,
          border: c.error.withValues(alpha: 0.3),
          icon: HugeIcons.strokeRoundedCancel01,
        );
      case ValidationStatus.pendingReview:
        return _BadgeConfig(
          bg: c.warningContainer,
          fg: c.onWarningContainer,
          border: c.warning.withValues(alpha: 0.4),
          icon: HugeIcons.strokeRoundedClock01,
        );
      case ValidationStatus.inProgress:
        return _BadgeConfig(
          bg: c.infoContainer,
          fg: c.onInfoContainer,
          border: c.info.withValues(alpha: 0.3),
          icon: HugeIcons.strokeRoundedLoading01,
        );
    }
  }
}

class _BadgeConfig {
  final Color bg;
  final Color fg;
  final Color border;
  final HugeIconData icon;

  const _BadgeConfig({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });
}
