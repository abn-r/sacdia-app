import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/file_display_name.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/certificate_import_file.dart';
import 'certificate_proof_viewer.dart';

/// Proof card for the review header: thumbnail, file data and "Ver".
/// Opens the viewer even when the batch has no rows.
class CertificateProofSummary extends StatelessWidget {
  const CertificateProofSummary({
    super.key,
    required this.batchId,
    required this.files,
    this.localPath,
  });

  final String batchId;
  final List<CertificateImportFile> files;

  /// Just-uploaded local file: drawn as a real thumbnail and used without
  /// network by the viewer.
  final String? localPath;

  static bool isPdf(CertificateImportFile file) =>
      '${file.type} ${file.name}'.toLowerCase().contains('pdf');

  /// The file name worth showing, or null when the phone made it up
  /// (`image_picker_<uuid>.jpg`, a bare UUID). Shared rule: see
  /// [meaningfulFileName].
  static String? displayName(String name) => meaningfulFileName(name);

  String _meta(CertificateImportFile file) {
    final base = !isPdf(file)
        ? 'certificate_import.viewer.photo_one_page'.tr()
        : file.pageCount == null
            ? 'certificate_import.viewer.kind_pdf'.tr()
            : (file.pageCount == 1
                    ? 'certificate_import.viewer.pdf_pages_one'
                    : 'certificate_import.viewer.pdf_pages_other')
                .tr(namedArgs: {'count': '${file.pageCount}'});
    final more = files.length - 1;
    if (more < 1) return base;
    final extra = (more == 1
            ? 'certificate_import.viewer.more_files_one'
            : 'certificate_import.viewer.more_files_other')
        .tr(namedArgs: {'count': '$more'});
    return '$base · $extra';
  }

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final c = context.sac;
    final file = files.first;
    final local = localPath;
    final showImage = local != null && !isPdf(file) && File(local).existsSync();

    Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      child: SizedBox(
        width: 32,
        height: 40,
        child: showImage
            ? Image.file(File(local), fit: BoxFit.cover, cacheWidth: 96)
            : ColoredBox(
                color: c.surfaceVariant,
                child: Center(
                  child: HugeIcon(
                    icon: isPdf(file)
                        ? HugeIcons.strokeRoundedPdf01
                        : HugeIcons.strokeRoundedImage01,
                    color: c.textSecondary,
                    size: 20,
                  ),
                ),
              ),
      ),
    );
    // Only a real image can fly to the viewer; an icon would be a false trip.
    if (showImage) {
      thumb = HeroMode(
        enabled: !SacMotion.reduceMotionOf(context),
        child: Hero(
          tag: CertificateProofViewer.heroTagFor(file.id),
          child: thumb,
        ),
      );
    }

    return Semantics(
      button: true,
      container: true,
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: BorderSide(color: c.border),
        ),
        child: SacInkWell(
          onTap: () => CertificateProofViewer.open(
            context,
            batchId: batchId,
            file: file,
            localPath: local,
          ),
          pressedScale: SacMotion.rowPressScale,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Row(
                children: [
                  ExcludeSemantics(child: thumb),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'certificate_import.viewer.title'.tr(),
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _meta(file),
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            height: 1.35,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: c.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
