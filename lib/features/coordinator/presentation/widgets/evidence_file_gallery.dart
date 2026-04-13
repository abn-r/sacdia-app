import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_review_item.dart';

/// Galería de archivos de evidencia.
///
/// Muestra imágenes como miniaturas en cuadrícula y PDFs con un ícono
/// de documento con el nombre. Al tocar una imagen se abre en pantalla completa.
class EvidenceFileGallery extends StatelessWidget {
  final List<EvidenceFile> files;

  const EvidenceFileGallery({super.key, required this.files});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (files.isEmpty) {
      return Center(
        child: Column(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFolder01,
              size: 40,
              color: c.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              'Sin archivos adjuntos',
              style: TextStyle(fontSize: 13, color: c.textTertiary),
            ),
          ],
        ),
      );
    }

    final imageFiles = files.where((f) => f.isImage).toList();
    final otherFiles = files.where((f) => !f.isImage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Image grid ────────────────────────────────────────────────────
        if (imageFiles.isNotEmpty) ...[
          GridView.builder(
            // shrinkWrap OK: imageFiles is a subset of evidence images per
            // honor — naturally bounded. Lives inside a Column (non-scrollable)
            // so intrinsic height is required.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: imageFiles.length,
            itemBuilder: (context, index) {
              final file = imageFiles[index];
              return _ImageThumbnail(
                file: file,
                allImages: imageFiles,
                initialIndex: index,
              );
            },
          ),
        ],

        // ── Non-image files ───────────────────────────────────────────────
        if (otherFiles.isNotEmpty) ...[
          if (imageFiles.isNotEmpty) const SizedBox(height: 10),
          ...otherFiles.map((file) => _DocumentTile(file: file, c: c)),
        ],
      ],
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final EvidenceFile file;
  final List<EvidenceFile> allImages;
  final int initialIndex;

  const _ImageThumbnail({
    required this.file,
    required this.allImages,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.network(
            file.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: c.surfaceVariant,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: 24,
                color: c.textTertiary,
              ),
            ),
            loadingBuilder: (_, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: c.surfaceVariant,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(
          images: allImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final EvidenceFile file;
  final SacColors c;

  const _DocumentTile({required this.file, required this.c});

  @override
  Widget build(BuildContext context) {
    final isPdf = file.isPdf;
    final icon = isPdf
        ? HugeIcons.strokeRoundedFile01
        : HugeIcons.strokeRoundedAttachment01;
    final iconColor = isPdf ? AppColors.error : AppColors.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: HugeIcon(icon: icon, size: 18, color: iconColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name ?? (isPdf ? 'Documento PDF' : 'Archivo'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (file.mimeType != null)
                  Text(
                    file.mimeType!,
                    style: TextStyle(fontSize: 11, color: c.textTertiary),
                  ),
              ],
            ),
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedDownload01,
            size: 16,
            color: c.textTertiary,
          ),
        ],
      ),
    );
  }
}

// ── Fullscreen image viewer ───────────────────────────────────────────────────

class _FullscreenImageViewer extends StatefulWidget {
  final List<EvidenceFile> images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final file = widget.images[index];
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                file.url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
