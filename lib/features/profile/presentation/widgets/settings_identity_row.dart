import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';

/// First row of the settings index: avatar, full name and email. Tapping it
/// opens the profile editor ([onTap]).
class SettingsIdentityRow extends StatelessWidget {
  const SettingsIdentityRow({
    super.key,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.onTap,
  });

  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback onTap;

  static const double _avatarSize = 52;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return SacInkWell(
      onTap: onTap,
      pressedScale: SacMotion.rowPressScale,
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: _avatarSize,
              height: _avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SacAccent.of(context).light,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasAvatar
                  ? SacProfileImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 156,
                      memCacheHeight: 156,
                      errorWidget: (_, __, ___) => _Initials(name: name),
                    )
                  : _Initials(name: name),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textTertiary,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w[0].toUpperCase()).join();
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: SacFontSize.headlineSmall,
          fontWeight: FontWeight.w700,
          color: SacAccent.of(context).color,
        ),
      ),
    );
  }
}
