import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/member_insurance.dart';

/// Badge de estado de seguro de un miembro.
///
/// Muestra un indicador de color con el texto del estado.
/// [compact] reduce el padding para usarse en tarjetas pequeñas.
class InsuranceStatusBadge extends StatelessWidget {
  final InsuranceStatus status;
  final bool compact;
  final bool large;

  const InsuranceStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _badgeConfig(status);

    final fontSize = large ? 14.0 : (compact ? 10.5 : 12.0);
    final iconSize = large ? 16.0 : (compact ? 12.0 : 13.0);
    final hPad = large ? 14.0 : (compact ? 8.0 : 10.0);
    final vPad = large ? 8.0 : (compact ? 4.0 : 5.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        border: Border.all(color: config.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: config.icon,
            size: iconSize,
            color: config.fg,
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: config.fg,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _badgeConfig(InsuranceStatus status) {
    switch (status) {
      case InsuranceStatus.asegurado:
        return _BadgeConfig(
          bg: AppColors.secondaryLight,
          fg: AppColors.secondaryDark,
          border: AppColors.secondary.withValues(alpha: 0.4),
          icon: HugeIcons.strokeRoundedShield01,
        );
      case InsuranceStatus.vencido:
        return _BadgeConfig(
          bg: AppColors.accentLight,
          fg: AppColors.accentDark,
          border: AppColors.accent.withValues(alpha: 0.4),
          icon: HugeIcons.strokeRoundedAlert02,
        );
      case InsuranceStatus.sinSeguro:
        return _BadgeConfig(
          bg: AppColors.errorLight,
          fg: AppColors.errorDark,
          border: AppColors.error.withValues(alpha: 0.3),
          icon: HugeIcons.strokeRoundedShieldEnergy,
        );
    }
  }
}

class _BadgeConfig {
  final Color bg;
  final Color fg;
  final Color border;
  final List<List<dynamic>> icon;

  const _BadgeConfig({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });
}
