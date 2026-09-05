import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/notification_item.dart';

/// Badge visual que identifica el tipo/target de una notificación.
///
/// Si el backend envía `source`, prioriza una categoría de producto
/// (agenda, logro, revisión, fecha importante). Si no, cae al target técnico.
class NotificationTypeBadge extends StatelessWidget {
  final NotificationTargetType type;
  final String? source;
  final double size;

  const NotificationTypeBadge({
    super.key,
    required this.type,
    this.source,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final config = notificationVisualConfig(source: source, targetType: type);
    final iconSize = size * 0.46;
    final background = Color.alphaBlend(
      config.iconColor.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10,
      ),
      c.surfaceVariant,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: config.iconColor.withValues(alpha: 0.14)),
      ),
      child: Center(
        child: HugeIcon(
          icon: config.icon,
          size: iconSize,
          color: config.iconColor,
        ),
      ),
    );
  }
}

NotificationVisualConfig notificationVisualConfig({
  String? source,
  required NotificationTargetType targetType,
}) {
  final normalizedSource = source?.trim().toLowerCase() ?? '';

  if (normalizedSource.startsWith('activities:')) {
    return NotificationVisualConfig(
      label: 'Agenda',
      icon: HugeIcons.strokeRoundedCalendar03,
      iconColor: AppColors.info,
      backgroundColor: AppColors.info.withValues(alpha: 0.12),
    );
  }

  if (normalizedSource.startsWith('achievements:') ||
      normalizedSource.startsWith('master_honors:') ||
      normalizedSource.startsWith('units:member_of_month')) {
    return NotificationVisualConfig(
      label: 'Logro',
      icon: HugeIcons.strokeRoundedAward01,
      iconColor: AppColors.accentDark,
      backgroundColor: AppColors.accent.withValues(alpha: 0.18),
    );
  }

  if (normalizedSource.startsWith('validation:') ||
      normalizedSource.startsWith('requests:') ||
      normalizedSource.startsWith('membership_requests:') ||
      normalizedSource.startsWith('investiture:')) {
    return NotificationVisualConfig(
      label: 'Revisión',
      icon: HugeIcons.strokeRoundedDocumentValidation,
      iconColor: AppColors.primaryDark,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
    );
  }

  if (normalizedSource.startsWith('monthly_reports:') ||
      normalizedSource.startsWith('camporees:')) {
    return NotificationVisualConfig(
      label: 'Fecha importante',
      icon: HugeIcons.strokeRoundedClock04,
      iconColor: AppColors.observedDark,
      backgroundColor: AppColors.observedBg,
    );
  }

  if (normalizedSource.startsWith('system_alert:')) {
    return NotificationVisualConfig(
      label: 'Sistema',
      icon: HugeIcons.strokeRoundedAlert02,
      iconColor: AppColors.error,
      backgroundColor: AppColors.error.withValues(alpha: 0.12),
    );
  }

  switch (targetType) {
    case NotificationTargetType.direct:
      return NotificationVisualConfig(
        label: 'Personal',
        icon: HugeIcons.strokeRoundedUser,
        iconColor: AppColors.info,
        backgroundColor: AppColors.info.withValues(alpha: 0.12),
      );
    case NotificationTargetType.broadcast:
      return NotificationVisualConfig(
        label: 'Comunicado',
        icon: HugeIcons.strokeRoundedMegaphone01,
        iconColor: AppColors.primaryDark,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      );
    case NotificationTargetType.club:
      return NotificationVisualConfig(
        label: 'Club',
        icon: HugeIcons.strokeRoundedUserGroup,
        iconColor: AppColors.secondaryDark,
        backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
      );
    case NotificationTargetType.sectionRole:
      return NotificationVisualConfig(
        label: 'Equipo',
        icon: HugeIcons.strokeRoundedShieldUser,
        iconColor: AppColors.observedDark,
        backgroundColor: AppColors.observedBg,
      );
    case NotificationTargetType.globalRole:
      return NotificationVisualConfig(
        label: 'Campo',
        icon: HugeIcons.strokeRoundedCrown,
        iconColor: AppColors.error,
        backgroundColor: AppColors.error.withValues(alpha: 0.12),
      );
    case NotificationTargetType.unknown:
      return const NotificationVisualConfig(
        label: 'Aviso',
        icon: HugeIcons.strokeRoundedNotification01,
        // Gris neutro legible en ambos modos; el widget mezcla iconColor
        // sobre la superficie del tema para el fondo real.
        iconColor: AppColors.pendingDark,
        backgroundColor: AppColors.pendingBg,
      );
  }
}

class NotificationVisualConfig {
  final String label;
  final HugeIconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const NotificationVisualConfig({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}
