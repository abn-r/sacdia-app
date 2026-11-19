import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import 'setting_tile.dart';

/// What the user chose in the profile photo sheet.
enum ProfilePhotoAction { camera, gallery, remove }

/// "Profile photo" sheet: take a photo, pick from the gallery and, only when
/// the user has a photo ([hasPhoto]), remove it (destructive, always last).
///
/// Returns the chosen [ProfilePhotoAction], or null when dismissed.
Future<ProfilePhotoAction?> showProfilePhotoSheet(
  BuildContext context, {
  required bool hasPhoto,
}) {
  return showSacSheet<ProfilePhotoAction>(
    context: context,
    builder: (_) => _ProfilePhotoSheet(hasPhoto: hasPhoto),
  );
}

class _ProfilePhotoSheet extends StatelessWidget {
  const _ProfilePhotoSheet({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    void choose(ProfilePhotoAction action) => Navigator.of(context).pop(action);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(title: 'profile.edit.photo_sheet_title'.tr()),
          SettingTile(
            icon: HugeIcons.strokeRoundedCamera01,
            title: 'profile.edit.photo_take'.tr(),
            trailing: const SizedBox.shrink(),
            onTap: () => choose(ProfilePhotoAction.camera),
          ),
          SettingTile(
            icon: HugeIcons.strokeRoundedImage01,
            title: 'profile.edit.photo_pick'.tr(),
            trailing: const SizedBox.shrink(),
            onTap: () => choose(ProfilePhotoAction.gallery),
          ),
          if (hasPhoto) ...[
            Divider(height: 1, thickness: 1, indent: 60, color: c.divider),
            SettingTile(
              icon: HugeIcons.strokeRoundedDelete02,
              title: 'profile.edit.photo_remove'.tr(),
              iconColor: c.error,
              titleColor: c.error,
              trailing: const SizedBox.shrink(),
              onTap: () => choose(ProfilePhotoAction.remove),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
