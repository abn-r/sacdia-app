import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/certificate_import_payloads.dart';
import '../utils/import_formatters.dart';

/// The proof the member just picked: a real thumbnail for a photo, a page icon
/// for a PDF, "Tu comprobante" and "Foto · 1.2 MB" / "PDF · 340 KB". Never the
/// technical file name (`image_picker_8E67…`). "Cambiar" picks another one.
class ImportProofPreview extends StatelessWidget {
  const ImportProofPreview({
    super.key,
    required this.proof,
    required this.onChange,
  });

  final CertificateImportLocalProof proof;
  final VoidCallback? onChange;

  bool get _isPdf => proof.mimeType.toLowerCase() == 'application/pdf';

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final size = importFileSize(proof.fileSize);
    final detail = (_isPdf
            ? 'certificate_import.upload.proof_pdf'
            : 'certificate_import.upload.proof_photo')
        .tr(namedArgs: {'size': size});

    Widget icon() => ColoredBox(
          color: c.surfaceVariant,
          child: Center(
            child: HugeIcon(
              icon: _isPdf
                  ? HugeIcons.strokeRoundedPdf01
                  : HugeIcons.strokeRoundedImage01,
              color: c.textSecondary,
              size: 24,
            ),
          ),
        );

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      child: SizedBox(
        width: 48,
        height: 60,
        child: _isPdf
            ? icon()
            : Image.file(
                File(proof.localPath),
                fit: BoxFit.cover,
                cacheWidth: 144,
                errorBuilder: (_, __, ___) => icon(),
              ),
      ),
    );

    return Container(
      key: const ValueKey('import-proof-preview'),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: thumb),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'certificate_import.viewer.title'.tr(),
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SacInkWell(
            onTap: onChange,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'certificate_import.upload.change'.tr(),
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      fontWeight: FontWeight.w600,
                      color: accent.dark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
