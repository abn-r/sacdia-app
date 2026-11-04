import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/sac_accent.dart';
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
    final config = notificationVisualConfig(
      context: context,
      source: source,
      targetType: type,
    );
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
  required BuildContext context,
  String? source,
  required NotificationTargetType targetType,
}) {
  final c = context.sac;
  final normalizedSource = source?.trim().toLowerCase() ?? '';

  if (normalizedSource.startsWith('activities:')) {
    return NotificationVisualConfig(
      label: 'notifications.types.agenda'.tr(),
      icon: HugeIcons.strokeRoundedCalendar03,
      iconColor: c.onInfoContainer,
      backgroundColor: c.infoContainer,
    );
  }

  if (normalizedSource.startsWith('achievements:') ||
      normalizedSource.startsWith('master_honors:') ||
      normalizedSource.startsWith('units:member_of_month')) {
    return NotificationVisualConfig(
      label: 'notifications.types.achievement'.tr(),
      icon: HugeIcons.strokeRoundedAward01,
      iconColor: c.onWarningContainer,
      backgroundColor: c.warningContainer,
    );
  }

  if (normalizedSource.startsWith('validation:') ||
      normalizedSource.startsWith('requests:') ||
      normalizedSource.startsWith('membership_requests:') ||
      normalizedSource.startsWith('investiture:')) {
    return NotificationVisualConfig(
      label: 'notifications.types.review'.tr(),
      icon: HugeIcons.strokeRoundedDocumentValidation,
      iconColor: SacAccent.of(context).dark,
      backgroundColor: SacAccent.of(context).color.withValues(alpha: 0.12),
    );
  }

  if (normalizedSource.startsWith('monthly_reports:') ||
      normalizedSource.startsWith('camporees:')) {
    return NotificationVisualConfig(
      label: 'notifications.types.important_date'.tr(),
      icon: HugeIcons.strokeRoundedClock04,
      iconColor: c.onWarningContainer,
      backgroundColor: c.warningContainer,
    );
  }

  if (normalizedSource.startsWith('system_alert:')) {
    return NotificationVisualConfig(
      label: 'notifications.types.system'.tr(),
      icon: HugeIcons.strokeRoundedAlert02,
      iconColor: c.onErrorContainer,
      backgroundColor: c.errorContainer,
    );
  }

  switch (targetType) {
    case NotificationTargetType.direct:
      return NotificationVisualConfig(
        label: 'notifications.types.personal'.tr(),
        icon: HugeIcons.strokeRoundedUser,
        iconColor: c.onInfoContainer,
        backgroundColor: c.infoContainer,
      );
    case NotificationTargetType.broadcast:
      return NotificationVisualConfig(
        label: 'notifications.types.announcement'.tr(),
        icon: HugeIcons.strokeRoundedMegaphone01,
        iconColor: SacAccent.of(context).dark,
        backgroundColor: SacAccent.of(context).color.withValues(alpha: 0.12),
      );
    case NotificationTargetType.club:
      return NotificationVisualConfig(
        label: 'notifications.types.club'.tr(),
        icon: HugeIcons.strokeRoundedUserGroup,
        iconColor: c.onSuccessContainer,
        backgroundColor: c.successContainer,
      );
    case NotificationTargetType.sectionRole:
      return NotificationVisualConfig(
        label: 'notifications.types.team'.tr(),
        icon: HugeIcons.strokeRoundedShieldUser,
        iconColor: c.onWarningContainer,
        backgroundColor: c.warningContainer,
      );
    case NotificationTargetType.globalRole:
      return NotificationVisualConfig(
        label: 'notifications.types.field'.tr(),
        icon: HugeIcons.strokeRoundedCrown,
        iconColor: c.onErrorContainer,
        backgroundColor: c.errorContainer,
      );
    case NotificationTargetType.unknown:
      return NotificationVisualConfig(
        label: 'notifications.types.notice'.tr(),
        icon: HugeIcons.strokeRoundedNotification01,
        // Gris neutro legible en ambos modos; el widget mezcla iconColor
        // sobre la superficie del tema para el fondo real.
        iconColor: c.textSecondary,
        backgroundColor: c.surfaceVariant,
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
