import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_image_viewer.dart';
import '../../../../core/widgets/sac_pdf_viewer.dart';
import '../../domain/entities/requirement_evidence.dart';

/// Grid de miniaturas de archivos de evidencia de un requerimiento.
///
/// Identico al EvidenceFileGrid de carpeta_evidencias pero tipado
/// para [RequirementEvidence].
class RequirementEvidenceGrid extends StatelessWidget {
  final List<RequirementEvidence> files;
  final bool canDelete;
  final void Function(RequirementEvidence file)? onDelete;

  const RequirementEvidenceGrid({
    super.key,
    required this.files,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileCell(
          file: file,
          evidenceNumber: index + 1,
          canDelete: canDelete,
          onDelete: onDelete != null ? () => onDelete!(file) : null,
        );
      },
    );
  }
}

class _FileCell extends StatelessWidget {
  final RequirementEvidence file;
  final int evidenceNumber;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _FileCell({
    required this.file,
    required this.evidenceNumber,
    required this.canDelete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM', 'es');

    return GestureDetector(
      onTap: () => _openViewer(context),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail / icon
                Expanded(
                  child: file.isImage
                      ? _ImageThumbnail(url: file.url)
                      : const _PdfIcon(),
                ),

                // Metadata
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 5),
                  color: c.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evidencia $evidenceNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      Text(
                        '${file.uploadedByName} · ${dateFormat.format(file.uploadedAt.toLocal())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Boton de eliminar
          if (canDelete && onDelete != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.sac.shadow,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context) {
    if (file.isImage) {
      SacImageViewer.show(context, imageUrl: file.url);
    } else if (file.isPdf) {
      SacPdfViewer.show(context, pdfUrl: file.url, title: file.fileName);
    }
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String url;

  const _ImageThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _FallbackIcon(),
      progressIndicatorBuilder: (context, url, downloadProgress) {
        return Container(
          color: AppColors.primaryLight,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: downloadProgress.progress,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }
}

class _PdfIcon extends StatelessWidget {
  const _PdfIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.errorLight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedPdf01,
            size: 32,
            color: AppColors.error,
          ),
          const SizedBox(height: 4),
          Text(
            'PDF',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedImage01,
          size: 28,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
