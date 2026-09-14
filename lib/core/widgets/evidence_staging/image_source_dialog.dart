import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../../theme/app_colors.dart';

/// Shows a bottom sheet asking the user to pick an image source.
///
/// Returns [ImageSource.camera] for single capture or
/// [ImageSource.gallery] for multi-select. Returns `null` if dismissed.
Future<ImageSource?> showImageSourceDialog(BuildContext context) {
  return showSacSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SacSheetHeader(
            title: tr('core.evidence_staging.image_source_title'),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCamera01,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
            ),
            title: Text(tr('core.evidence_staging.image_source_camera')),
            subtitle: Text(tr('core.evidence_staging.image_source_camera_sub')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
            ),
            title: Text(tr('core.evidence_staging.image_source_gallery')),
            subtitle:
                Text(tr('core.evidence_staging.image_source_gallery_sub')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
