import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/file_display_name.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

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
        ? 'certificate_import.viewer.kind_image'.tr()
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
    final theme = Theme.of(context).textTheme;
    final local = localPath;
    final showImage = local != null && !isPdf(file) && File(local).existsSync();

    Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      child: SizedBox(
        width: 48,
        height: 60,
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
                    size: 24,
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
      child: SacCard(
        onTap: () => CertificateProofViewer.open(
          context,
          batchId: batchId,
          file: file,
          localPath: local,
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
                    style: theme.titleSmall?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (displayName(file.name) case final name?)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  Text(
                    _meta(file),
                    style: theme.bodySmall?.copyWith(color: c.textTertiary),
                  ),
                ],
              ),
            ),
            Text(
              'certificate_import.viewer.view'.tr(),
              style: theme.labelLarge?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(width: 4),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: c.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
