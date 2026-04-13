import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';

/// Encabezado de bienvenida del dashboard - Estilo "Scout Vibrante"
///
/// Fondo blanco, saludo contextual (mañana/tarde/noche),
/// nombre del usuario, avatar circular a la derecha.
/// Avatar size adapts to screen width via Responsive.smallAvatarSize.
class WelcomeHeader extends StatelessWidget {
  final String userName;
  final String? userAvatar;

  /// Callback opcional para navegar a la bandeja de notificaciones.
  /// Si es null, el icono de campana no se muestra.
  final VoidCallback? onNotificationsTap;

  const WelcomeHeader({
    super.key,
    required this.userName,
    this.userAvatar,
    this.onNotificationsTap,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '¡Buenos días';
    if (hour < 18) return '¡Buenas tardes';
    return '¡Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final firstName = userName.split(' ').first;
    final avatarSize = Responsive.smallAvatarSize(context);
    final hPad = Responsive.horizontalPadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
      child: Row(
        children: [
          // Greeting and name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.sac.textSecondary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$firstName!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.sac.text,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Botón de notificaciones
          if (onNotificationsTap != null) ...[
            IconButton(
              onPressed: onNotificationsTap,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedNotification01,
                size: 24,
                color: AppColors.lightText,
              ),
              tooltip: 'Notificaciones',
            ),
          ],

          // Avatar — size adapts to screen
          GestureDetector(
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryLight,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: userAvatar != null && userAvatar!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: userAvatar!,
                        fit: BoxFit.cover,
                        memCacheWidth: 132,
                        memCacheHeight: 132,
                        placeholder: (_, __) => _AvatarFallback(
                          initial: firstName,
                        ),
                        errorWidget: (_, __, ___) => _AvatarFallback(
                          initial: firstName,
                        ),
                      )
                    : _AvatarFallback(initial: firstName),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initial;
  const _AvatarFallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      child: Text(
        initial.isNotEmpty ? initial[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
