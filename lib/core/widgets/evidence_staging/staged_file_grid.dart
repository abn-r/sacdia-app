import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/sac_colors.dart';
import '../sac_image_viewer.dart';
import '../sac_pdf_viewer.dart';
import 'staged_file.dart';

/// Unified grid for displaying both remote (uploaded) and local (staged) files.
///
/// Delete behavior differs by status:
/// - Local files: instant remove (no confirmation).
/// - Remote files: confirmation dialog before calling [onDeleteRemote].
class StagedFileGrid extends StatelessWidget {
  final List<StagedFile> files;
  final int maxFiles;
  final bool canModify;
  final void Function(StagedFile file) onRemoveLocal;
  final void Function(StagedFile file) onDeleteRemote;

  const StagedFileGrid({
    super.key,
    required this.files,
    required this.maxFiles,
    required this.canModify,
    required this.onRemoveLocal,
    required this.onDeleteRemote,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    final c = context.sac;
    final totalFiles = files.length;
    final excess = totalFiles - maxFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          // shrinkWrap OK: bounded to maxFiles items max; lives inside a
          // Column (non-scrollable), so height must be intrinsically defined.
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
            // A local file is "excess" if its position is beyond maxFiles
            final isExcess = file.isLocal && index >= maxFiles;

            return _StagedFileCell(
              file: file,
              isExcess: isExcess,
              canModify: canModify,
              onRemoveLocal: () => onRemoveLocal(file),
              onDeleteRemote: () => _confirmRemoteDelete(context, file),
            );
          },
        ),
        const SizedBox(height: 10),
        // File counter
        Center(
          child: Text(
            '$totalFiles de $maxFiles archivos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: excess > 0 ? AppColors.error : c.textSecondary,
            ),
          ),
        ),
        // Excess warning
        if (excess > 0) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Tienes $excess ${excess == 1 ? 'archivo' : 'archivos'} de más, eliminá algunos para continuar',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmRemoteDelete(
      BuildContext context, StagedFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${file.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      onDeleteRemote(file);
    }
  }
}

// ── Individual file cell ──────────────────────────────────────────────────────

class _StagedFileCell extends StatelessWidget {
  final StagedFile file;
  final bool isExcess;
  final bool canModify;
  final VoidCallback onRemoveLocal;
  final VoidCallback onDeleteRemote;

  const _StagedFileCell({
    required this.file,
    required this.isExcess,
    required this.canModify,
    required this.onRemoveLocal,
    required this.onDeleteRemote,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM', 'es');

    return GestureDetector(
      onTap: () => _openViewer(context),
      child: Stack(
        children: [
          // Main container
          Container(
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: file.isLocal
                  ? null // Dashed border handled by foregroundDecoration below
                  : Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            foregroundDecoration: file.isLocal
                ? _DashedBorderDecoration(
                    color: isExcess ? AppColors.error : AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                    strokeWidth: 2,
                    dashWidth: 6,
                    dashGap: 4,
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail / icon
                Expanded(child: _buildThumbnail()),

                // Metadata footer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  color: c.surface,
                  child: file.isRemote
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.uploadedBy ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                            if (file.uploadedAt != null)
                              Text(
                                dateFormat.format(file.uploadedAt!.toLocal()),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: c.textTertiary,
                                ),
                              ),
                          ],
                        )
                      : Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // ── Badges ────────────────────────────────────────────────────────

          // Remote: green check badge (top-right)
          if (file.isRemote)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),

          // Local: "Nuevo" / "Extra" badge (top-right)
          if (file.isLocal)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isExcess ? AppColors.error : AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  isExcess ? 'Extra' : 'Nuevo',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // ── Delete buttons ────────────────────────────────────────────────

          // Local: instant remove (top-left)
          if (file.isLocal && canModify)
            Positioned(
              top: 4,
              left: 4,
              child: GestureDetector(
                onTap: onRemoveLocal,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.shadow,
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

          // Remote: delete with confirmation (top-left, only when canModify)
          if (file.isRemote && canModify)
            Positioned(
              top: 4,
              left: 4,
              child: GestureDetector(
                onTap: onDeleteRemote,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.shadow,
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

  Widget _buildThumbnail() {
    if (file.isPdf) {
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
            const Text(
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

    // Remote image thumbnail
    if (file.isRemote && file.remoteUrl != null) {
      return CachedNetworkImage(
        imageUrl: file.remoteUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _fallbackIcon(),
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

    // Local image: show from file
    if (file.isLocal && file.localPath != null) {
      return Image.file(
        File(file.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }

    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
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

  void _openViewer(BuildContext context) {
    if (file.isRemote && file.remoteUrl != null) {
      if (file.isImage) {
        SacImageViewer.show(context, imageUrl: file.remoteUrl!, title: file.name);
      } else if (file.isPdf) {
        SacPdfViewer.show(context, pdfSource: file.remoteUrl!, title: file.name);
      }
    } else if (file.isLocal && file.localPath != null && file.isImage) {
      // Local images: full-screen preview with InteractiveViewer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(file.name, style: const TextStyle(color: Colors.white)),
            ),
            body: Center(
              child: InteractiveViewer(
                child: Image.file(File(file.localPath!), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }
  }
}

// ── Dashed border decoration ──────────────────────────────────────────────────

class _DashedBorderDecoration extends Decoration {
  final Color color;
  final BorderRadius borderRadius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  const _DashedBorderDecoration({
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 2,
    this.dashWidth = 6,
    this.dashGap = 4,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DashedBorderPainter(
      color: color,
      borderRadius: borderRadius,
      strokeWidth: strokeWidth,
      dashWidth: dashWidth,
      dashGap: dashGap,
    );
  }
}

class _DashedBorderPainter extends BoxPainter {
  final Color color;
  final BorderRadius borderRadius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final rrect = borderRadius.toRRect(rect);
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Compute dashed path
    final dashedPath = _createDashedPath(path);
    canvas.drawPath(dashedPath, paint);
  }

  Path _createDashedPath(Path source) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length).toDouble();
        result.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashWidth + dashGap;
      }
    }
    return result;
  }
}
