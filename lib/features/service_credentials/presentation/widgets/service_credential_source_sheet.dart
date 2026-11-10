import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_sheet.dart';

/// Where the credential file comes from: camera, gallery or a PDF. The picker
/// itself is the one used for consent forms (`ConsentEvidencePicker`).
Future<ConsentSource?> showServiceCredentialSourceSheet(BuildContext context) {
  return showSacSheet<ConsentSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SacSheetHeader(title: 'service_credentials.upload.source_title'.tr()),
          _SourceTile(
            icon: HugeIcons.strokeRoundedCamera01,
            title: 'service_credentials.upload.source_camera'.tr(),
            onTap: () => Navigator.pop(ctx, ConsentSource.camera),
          ),
          _SourceTile(
            icon: HugeIcons.strokeRoundedImage01,
            title: 'service_credentials.upload.source_gallery'.tr(),
            onTap: () => Navigator.pop(ctx, ConsentSource.gallery),
          ),
          _SourceTile(
            icon: HugeIcons.strokeRoundedPdf01,
            title: 'service_credentials.upload.source_pdf'.tr(),
            onTap: () => Navigator.pop(ctx, ConsentSource.pdf),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final HugeIconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    return SacPressable(
      listenOnly: true,
      child: ListTile(
        enableFeedback: false,
        minTileHeight: 56,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.light,
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 22, color: accent.color),
          ),
        ),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}
