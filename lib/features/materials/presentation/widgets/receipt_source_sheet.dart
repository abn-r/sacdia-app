import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_settings.dart';
import '../../../../core/widgets/sac_sheet.dart';

/// Where the receipt file comes from.
enum ReceiptSource { camera, gallery, file }

/// Camera, gallery or file (PDF), same pattern as the other receipt uploads.
/// Resolves to null when dismissed.
Future<ReceiptSource?> showReceiptSourceSheet(BuildContext context) {
  return showSacSheet<ReceiptSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: ctx.sac.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SacSheetHeader(
                title: 'materials.receipt.source_title'.tr(),
                subtitle: 'materials.receipt.source_subtitle'.tr(),
              ),
              SacSettingsGroup(
                children: [
                  SacSettingsTile(
                    key: const ValueKey('receipt-source-camera'),
                    icon: HugeIcons.strokeRoundedCamera01,
                    title: 'materials.receipt.source_camera'.tr(),
                    onTap: () => Navigator.of(ctx).pop(ReceiptSource.camera),
                  ),
                  const SacSettingsDivider(),
                  SacSettingsTile(
                    key: const ValueKey('receipt-source-gallery'),
                    icon: HugeIcons.strokeRoundedImage01,
                    title: 'materials.receipt.source_gallery'.tr(),
                    onTap: () => Navigator.of(ctx).pop(ReceiptSource.gallery),
                  ),
                  const SacSettingsDivider(),
                  SacSettingsTile(
                    key: const ValueKey('receipt-source-file'),
                    icon: HugeIcons.strokeRoundedPdf01,
                    title: 'materials.receipt.source_file'.tr(),
                    subtitle: 'materials.receipt.source_file_hint'.tr(),
                    onTap: () => Navigator.of(ctx).pop(ReceiptSource.file),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
