import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';

/// Centered avatar of the edit profile screen with a camera badge and the
/// "Change photo" text button. Avatar, badge and button all call [onTap].
///
/// While [isBusy] (uploading or removing a photo) an accent progress ring wraps
/// the avatar and taps are blocked; [busyLabel] names the operation. A new photo crossfades in over [SacMotion.routeEnter]; reduced
/// motion swaps instantly.
class EditProfileAvatar extends StatelessWidget {
  const EditProfileAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.isBusy,
    required this.busyLabel,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final bool isBusy;
  final String busyLabel;
  final VoidCallback onTap;

  static const double avatarSize = 92;
  static const double _ringGap = 6;
  static const double _badgeSize = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final reduce = SacMotion.reduceMotionOf(context);
    const outer = avatarSize + _ringGap * 2;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Column(
        children: [
          Semantics(
            label: isBusy ? busyLabel : 'profile.edit.photo_semantics'.tr(),
            button: true,
            enabled: !isBusy,
            onTap: isBusy ? null : onTap,
            excludeSemantics: true,
            child: SacPressable(
              onTap: onTap,
              enabled: !isBusy,
              child: SizedBox(
                width: outer,
                height: outer,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (isBusy)
                      SizedBox(
                        key: const ValueKey('edit-profile-upload-ring'),
                        width: outer,
                        height: outer,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: accent.color,
                          backgroundColor: accent.light,
                        ),
                      ),
                    ClipOval(
                      child: SizedBox(
                        width: avatarSize,
                        height: avatarSize,
                        child: AnimatedSwitcher(
                          duration:
                              reduce ? Duration.zero : SacMotion.routeEnter,
                          switchInCurve: SacMotion.easeOut,
                          child: SizedBox.expand(
                            key: ValueKey(avatarUrl ?? 'initials'),
                            child: _Photo(name: name, url: avatarUrl),
                          ),
                        ),
                      ),
                    ),
                    if (!isBusy)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          key: const ValueKey('edit-profile-camera-badge'),
                          width: _badgeSize,
                          height: _badgeSize,
                          decoration: BoxDecoration(
                            color: accent.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.background, width: 2),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedCamera01,
                              color: accent.onColor,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SacButton.text(
            text: isBusy ? busyLabel : 'profile.edit.change_photo'.tr(),
            onPressed: isBusy ? null : onTap,
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    final initials = ColoredBox(
      color: accent.surface,
      child: Center(
        child: Text(
          name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U',
          style: TextStyle(
            fontSize: SacFontSize.metricSmall,
            fontWeight: FontWeight.w700,
            color: accent.color,
          ),
        ),
      ),
    );
    final photoUrl = url;
    if (photoUrl == null) return initials;
    return SacProfileImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      memCacheWidth: 276,
      memCacheHeight: 276,
      placeholder: (_, __) => ColoredBox(color: accent.surface),
      errorWidget: (_, __, ___) => initials,
    );
  }
}
