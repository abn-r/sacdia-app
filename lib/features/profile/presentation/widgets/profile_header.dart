import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/responsive.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

/// Header del perfil con estilo Apple (iOS-inspired):
/// - Sin gradiente, fondo blanco limpio
/// - Avatar con borde rojo de marca y fondo neutro
/// - Nombre en negro, email en gris secundario
class ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? avatar;
  final VoidCallback? onEditPhoto;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.email,
    this.avatar,
    this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final avatarRadius = Responsive.headerAvatarSize(context);
    final fallbackFontSize = (avatarRadius * 0.65).clamp(22.0, 44.0);

    final c = context.sac;

    return Container(
      // Fondo limpio — sin degradado
      color: c.background,
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          // ── Avatar ─────────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: avatarRadius,
                  // Fondo muy sutil cuando no hay foto
                  backgroundColor: AppColors.primarySurface,
                  backgroundImage:
                      avatar != null ? CachedNetworkImageProvider(avatar!) : null,
                  child: avatar == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: fallbackFontSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
              // Botón editar foto — pequeño, minimalista
              if (onEditPhoto != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onEditPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.border,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.sac.shadow,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        color: c.textSecondary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Nombre ─────────────────────────────────────────────
          Text(
            name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  letterSpacing: -0.3,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // ── Email ──────────────────────────────────────────────
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              color: c.textSecondary,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
