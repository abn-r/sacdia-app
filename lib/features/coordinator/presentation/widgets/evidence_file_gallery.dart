import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';

/// Attached files of an evidence in a 3-column grid.
///
/// Images show as thumbnails and open in the full-screen viewer (swipe between
/// the evidence images). PDFs open in the PDF viewer; any other file is shown
/// with a file icon and its truncated name.
class EvidenceFileGallery extends StatelessWidget {
  const EvidenceFileGallery({super.key, required this.files});

  final List<EvidenceFile> files;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Column(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedFolder01,
                size: 40,
                color: c.textTertiary,
              ),
              const SizedBox(height: 8),
              Text(
                'coordinator.evidence_review.gallery.no_files'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    final images = files.where((f) => f.isImage).toList();

    return GridView.builder(
      // shrinkWrap is fine here: the files of one evidence are a handful, and
      // the grid lives inside the screen's own scroll view.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        if (file.isImage) {
          return _ImageTile(
            file: file,
            onTap: () => _openImages(context, images, images.indexOf(file)),
          );
        }
        return _FileTile(
          file: file,
          onTap: file.isPdf
              ? () => SacPdfViewer.show(
                    context,
                    pdfSource: file.url,
                    title: file.name,
                  )
              : null,
        );
      },
    );
  }

  /// Full-screen viewer without share and without disk cache: evidence URLs
  /// are signed and expire, so they must not be persisted.
  void _openImages(
    BuildContext context,
    List<EvidenceFile> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      SacFadeThroughRoute(
        fullscreenDialog: true,
        builder: (_) => SacImageViewer.gallery(
          imageUrls: [for (final f in images) f.url],
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          allowShare: false,
          cacheNetwork: false,
        ),
      ),
    );
  }
}

String _fileLabel(EvidenceFile file) {
  final name = file.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  return file.isPdf
      ? 'coordinator.evidence_review.gallery.pdf_document'.tr()
      : 'coordinator.evidence_review.gallery.file'.tr();
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.file, required this.onTap});

  final EvidenceFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacPressable(
      onTap: onTap,
      semanticLabel: _fileLabel(file),
      // The border is painted over the image: a mostly white screenshot would
      // otherwise cover it and blend into the page, looking like loose content.
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          child: ColoredBox(
            color: c.surfaceVariant,
            child: Image.network(
              file.url,
              fit: BoxFit.cover,
              cacheWidth: 400,
              errorBuilder: (_, __, ___) => Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedImageNotFound01,
                  size: 24,
                  color: c.textTertiary,
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(child: SacLoadingSmall());
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, this.onTap});

  final EvidenceFile file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: file.isPdf
                  ? HugeIcons.strokeRoundedFile01
                  : HugeIcons.strokeRoundedAttachment01,
              size: 28,
              color: c.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              _fileLabel(file),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return Semantics(label: _fileLabel(file), child: tile);
    return SacPressable(
      onTap: onTap,
      semanticLabel: _fileLabel(file),
      child: tile,
    );
  }
}
