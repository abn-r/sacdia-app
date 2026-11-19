import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../theme/app_theme.dart';
import '../../theme/sac_colors.dart';
import '../sac_settings.dart';
import '../sac_sheet.dart';

/// Where a new evidence file comes from.
enum EvidenceSource { camera, gallery, pdf }

/// Camera, gallery or PDF, in the same sheet the materials receipt upload
/// uses. Resolves to null when dismissed.
Future<EvidenceSource?> showEvidenceSourceSheet(BuildContext context) {
  return showSacSheet<EvidenceSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      key: const ValueKey('evidence-source-sheet'),
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
                title: 'core.evidence_staging.source_title'.tr(),
                subtitle: 'core.evidence_staging.source_subtitle'.tr(),
              ),
              SacSettingsGroup(
                children: [
                  SacSettingsTile(
                    key: const ValueKey('evidence-source-camera'),
                    icon: HugeIcons.strokeRoundedCamera01,
                    title: 'core.evidence_staging.source_camera'.tr(),
                    onTap: () => Navigator.of(ctx).pop(EvidenceSource.camera),
                  ),
                  const SacSettingsDivider(),
                  SacSettingsTile(
                    key: const ValueKey('evidence-source-gallery'),
                    icon: HugeIcons.strokeRoundedImage01,
                    title: 'core.evidence_staging.source_gallery'.tr(),
                    onTap: () => Navigator.of(ctx).pop(EvidenceSource.gallery),
                  ),
                  const SacSettingsDivider(),
                  SacSettingsTile(
                    key: const ValueKey('evidence-source-pdf'),
                    icon: HugeIcons.strokeRoundedPdf01,
                    title: 'core.evidence_staging.source_pdf'.tr(),
                    subtitle: 'core.evidence_staging.source_pdf_hint'.tr(),
                    onTap: () => Navigator.of(ctx).pop(EvidenceSource.pdf),
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
