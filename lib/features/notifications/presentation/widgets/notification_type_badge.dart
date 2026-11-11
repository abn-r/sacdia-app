import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/class_tone.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/notification_item.dart';

/// Badge visual que identifica el tipo/target de una notificación: un cuadro
/// redondeado con el tinte de su categoría y el ícono en el tono accesible.
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
    final config = notificationVisualConfig(
      context: context,
      source: source,
      targetType: type,
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(
          size >= 48 ? AppTheme.radiusMD : AppTheme.radiusSM,
        ),
      ),
      child: HugeIcon(
        icon: config.icon,
        size: size * 0.5,
        color: config.iconColor,
      ),
    );
  }
}

/// Warm category colors from the app palette. Each one goes through
/// [ClassTone] so the tint and the icon/label shade read in both modes:
/// agenda teal, achievement amber, review violet, important date coral,
/// system red, personal blue.
NotificationVisualConfig notificationVisualConfig({
  required BuildContext context,
  String? source,
  required NotificationTargetType targetType,
}) {
  final c = context.sac;
  final normalizedSource = source?.trim().toLowerCase() ?? '';

  NotificationVisualConfig toned(
      String labelKey, HugeIconData icon, Color base) {
    final tone = ClassTone.of(context, base);
    return NotificationVisualConfig(
      label: labelKey.tr(),
      icon: icon,
      iconColor: tone.onContainer,
      backgroundColor: tone.container,
      toneColor: base,
    );
  }

  if (normalizedSource.startsWith('activities:')) {
    return toned('notifications.types.agenda',
        HugeIcons.strokeRoundedCalendar03, AppColors.secondary);
  }

  if (normalizedSource.startsWith('achievements:') ||
      normalizedSource.startsWith('master_honors:') ||
      normalizedSource.startsWith('units:member_of_month')) {
    return toned('notifications.types.achievement',
        HugeIcons.strokeRoundedAward01, AppColors.accent);
  }

  if (normalizedSource.startsWith('validation:') ||
      normalizedSource.startsWith('requests:') ||
      normalizedSource.startsWith('membership_requests:') ||
      normalizedSource.startsWith('investiture:')) {
    return toned('notifications.types.review',
        HugeIcons.strokeRoundedDocumentValidation, AppColors.colorViajero);
  }

  if (normalizedSource.startsWith('monthly_reports:') ||
      normalizedSource.startsWith('finances:') ||
      normalizedSource.startsWith('camporees:')) {
    return toned('notifications.types.important_date',
        HugeIcons.strokeRoundedClock04, AppColors.primary);
  }

  if (normalizedSource.startsWith('system_alert:')) {
    return toned('notifications.types.system', HugeIcons.strokeRoundedAlert02,
        AppColors.error);
  }

  switch (targetType) {
    case NotificationTargetType.direct:
      return toned('notifications.types.personal', HugeIcons.strokeRoundedUser,
          AppColors.info);
    case NotificationTargetType.broadcast:
      return toned('notifications.types.announcement',
          HugeIcons.strokeRoundedMegaphone01, AppColors.primary);
    case NotificationTargetType.club:
      return toned('notifications.types.club', HugeIcons.strokeRoundedUserGroup,
          AppColors.secondary);
    case NotificationTargetType.sectionRole:
      return toned('notifications.types.team',
          HugeIcons.strokeRoundedShieldUser, AppColors.accent);
    case NotificationTargetType.globalRole:
      return toned('notifications.types.field', HugeIcons.strokeRoundedCrown,
          AppColors.colorViajero);
    case NotificationTargetType.unknown:
      return NotificationVisualConfig(
        label: 'notifications.types.notice'.tr(),
        icon: HugeIcons.strokeRoundedNotification01,
        iconColor: c.textSecondary,
        backgroundColor: c.surfaceVariant,
        toneColor: c.textTertiary,
      );
  }
}

class NotificationVisualConfig {
  final String label;
  final HugeIconData icon;

  /// Icon and label shade, readable on [backgroundColor] and on the card.
  final Color iconColor;

  /// Soft tint of the category for the icon well.
  final Color backgroundColor;

  /// The category's base color, for lighter washes (detail message box).
  final Color toneColor;

  const NotificationVisualConfig({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.toneColor,
  });
}
