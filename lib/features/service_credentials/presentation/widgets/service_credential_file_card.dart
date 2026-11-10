import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/file_display_name.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';

/// The chosen file before uploading: thumbnail (image) or PDF icon, name, size
/// and, when [onChange] is set, a compact «Cambiar» action.
class ServiceCredentialFileCard extends StatelessWidget {
  const ServiceCredentialFileCard({
    super.key,
    required this.file,
    this.onChange,
  });

  final ConsentEvidenceLocalFile file;
  final VoidCallback? onChange;

  String get _size {
    final mb = file.sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(file.sizeBytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final title = meaningfulFileName(file.name) ??
        (file.isPdf
            ? 'service_credentials.file_kind.pdf'.tr()
            : 'service_credentials.file_kind.photo'.tr());

    Widget placeholder() => Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: accent.light,
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Center(
            child: HugeIcon(
              icon: file.isPdf
                  ? HugeIcons.strokeRoundedPdf01
                  : HugeIcons.strokeRoundedImage01,
              size: 26,
              color: accent.color,
            ),
          ),
        );

    return SacCard(
      child: Row(
        children: [
          if (file.isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              child: Image.file(
                File(file.path),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                cacheWidth: 112,
                errorBuilder: (_, __, ___) => placeholder(),
              ),
            )
          else
            placeholder(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _size,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onChange != null) ...[
            const SizedBox(width: 8),
            SacButton.text(
              text: 'service_credentials.upload.change_file'.tr(),
              onPressed: onChange,
            ),
          ],
        ],
      ),
    );
  }
}
