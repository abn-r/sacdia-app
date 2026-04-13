import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/notification_item.dart';

/// Badge visual que identifica el tipo/target de una notificación.
///
/// Muestra un icono con fondo de color diferenciado según el tipo:
/// - [NotificationTargetType.direct]      — azul + icono de usuario
/// - [NotificationTargetType.broadcast]   — púrpura + megáfono
/// - [NotificationTargetType.club]        — verde azulado + grupo de usuarios
/// - [NotificationTargetType.sectionRole] — ámbar + escudo-usuario
/// - [NotificationTargetType.globalRole]  — rojo + corona
/// - [NotificationTargetType.unknown]     — gris + campana
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
      case NotificationTargetType.direct:
        // Blue — direct message to a single user.
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedUser,
          iconColor: AppColors.info,
          backgroundColor: AppColors.info.withValues(alpha: 0.12),
        );
      case NotificationTargetType.broadcast:
        // Purple — broadcast to all users.
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedMegaphone01,
          iconColor: const Color(0xFF7C3AED),
          backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
        );
      case NotificationTargetType.club:
        // Teal — sent to all members of a club section.
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedUserGroup,
          iconColor: const Color(0xFF0D9488),
          backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
        );
      case NotificationTargetType.sectionRole:
        // Amber — sent to users with a specific role in a section.
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedShieldUser,
          iconColor: const Color(0xFFD97706),
          backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.12),
        );
      case NotificationTargetType.globalRole:
        // Red — sent to users with a global role.
        return _BadgeConfig(
          icon: HugeIcons.strokeRoundedCrown,
          iconColor: AppColors.error,
          backgroundColor: AppColors.error.withValues(alpha: 0.12),
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
  final HugeIconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _BadgeConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}
