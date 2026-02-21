import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/responsive.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget para el encabezado del perfil con foto y nombre.
/// Avatar radius scales with screen width via Responsive.headerAvatarSize.
/// Name and email have overflow guards.
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      avatar != null ? NetworkImage(avatar!) : null,
                  child: avatar == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: fallbackFontSize,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
              // Edit photo button
              if (onEditPhoto != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onEditPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Name — overflow guard
          Text(
            name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Email — overflow guard
          Text(
            email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
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
