import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/notification_item.dart';

/// Badge visual que identifica el tipo/target de una notificación.
///
/// Muestra un icono con fondo de color diferenciado según el tipo:
/// - [NotificationTargetType.broadcast] — megáfono naranja/acento
/// - [NotificationTargetType.direct] — sobre azul
/// - [NotificationTargetType.section] — grupo verde
/// - [NotificationTargetType.unknown] — campana gris
class NotificationTypeBadge extends StatelessWidget {
  final NotificationTargetType type;
  final double size;

  const NotificationTypeBadge({
    super.key,
    required this.type,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final config = _configFor(type);
    final iconSize = size * 0.5;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.28),
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

  _BadgeConfig _configFor(NotificationTargetType type) {
    switch (type) {
      case NotificationTargetType.broadcast:
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedMegaphone01,
          iconColor: AppColors.accentDark,
          backgroundColor: AppColors.accentLight,
        );
      case NotificationTargetType.direct:
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedMail01,
          iconColor: AppColors.info,
          backgroundColor: AppColors.info.withValues(alpha: 0.12),
        );
      case NotificationTargetType.section:
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedUserGroup,
          iconColor: AppColors.secondaryDark,
          backgroundColor: AppColors.secondaryLight,
        );
      case NotificationTargetType.unknown:
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedNotification01,
          iconColor: AppColors.lightTextTertiary,
          backgroundColor: AppColors.lightBorderLight,
        );
    }
  }
}

class _BadgeConfig {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _BadgeConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}
