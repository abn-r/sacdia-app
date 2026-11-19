import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../theme/sac_colors.dart';
import '../sac_image_viewer.dart';
import '../sac_pdf_viewer.dart';
import '../sac_dialog.dart';
import '../sac_pressable.dart';
import '../sac_top_bar.dart';
import 'staged_file.dart';
import '../../animations/motion_tokens.dart';
import '../../animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Unified grid for displaying both remote (uploaded) and local (staged) files.
///
/// Delete behavior differs by status:
/// - Local files: instant remove (no confirmation).
/// - Remote files: confirmation dialog before calling [onDeleteRemote].
///
/// When [onAdd] is set and [canModify] is true the grid ends with an "Add"
/// tile (hidden once [maxFiles] is reached) and the "N of M files" caption is
/// left to the screen, which shows it in its section title.
///
/// Motion: a file the user just picked scales 0.96 -> 1 and fades in; the ×
/// scales and fades it out ([SacMotion.press]) before the owner removes it;
/// the tiles after it then slide to their new cells. Files that arrive or
/// leave without the user doing it (a refresh, the upload finishing) just
/// swap. When the screen turns read-only the "Add" tile leaves the same way
/// and the × and "New" badges fade.
class StagedFileGrid extends StatefulWidget {
  final List<StagedFile> files;
  final int maxFiles;
  final bool canModify;
  final void Function(StagedFile file) onRemoveLocal;
  final FutureOr<void> Function(StagedFile file) onDeleteRemote;

  /// Opens the source sheet. Null keeps the grid without an add tile.
  final VoidCallback? onAdd;

  /// Shows the "N of M files" caption under the grid. Screens that print the
  /// count in their section title (the add-tile layout) turn it off.
  final bool showCounter;

  const StagedFileGrid({
    super.key,
    required this.files,
    required this.maxFiles,
    required this.canModify,
    required this.onRemoveLocal,
    required this.onDeleteRemote,
    this.onAdd,
    this.showCounter = true,
  });

  @override
  State<StagedFileGrid> createState() => _StagedFileGridState();
}

class _StagedFileGridState extends State<StagedFileGrid> {
  static const _columns = 3;
  static const _spacing = 10.0;
  static const _aspect = 0.82;

  /// Ids whose exit animation is running (or whose delete is in flight).
  final Set<String> _exiting = {};
  final Map<String, FutureOr<void> Function()> _pendingActions = {};

  /// Ids of files the user just picked: they animate in once.
  final Set<String> _enterIds = {};

  bool _addExiting = false;
  int _addSlot = 0;

  bool _showAdd(StagedFileGrid w) =>
      w.canModify && w.onAdd != null && w.files.length < w.maxFiles;

  @override
  void didUpdateWidget(StagedFileGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = {for (final f in oldWidget.files) f.id};
    final ids = {for (final f in widget.files) f.id};
    for (final f in widget.files) {
      if (f.isLocal && !oldIds.contains(f.id)) _enterIds.add(f.id);
    }
    _exiting.removeWhere((id) => !ids.contains(id));
    _enterIds.removeWhere((id) => !ids.contains(id));
    _pendingActions.removeWhere((id, _) => !ids.contains(id));

    final wasAdd = _showAdd(oldWidget);
    final isAdd = _showAdd(widget);
    if (wasAdd && !isAdd && !widget.canModify) {
      _addExiting = true;
      _addSlot = oldWidget.files.length;
    }
    if (isAdd) _addExiting = false;
  }

  void _beginExit(StagedFile file, FutureOr<void> Function() action) {
    if (_exiting.contains(file.id)) return;
    setState(() {
      _exiting.add(file.id);
      _pendingActions[file.id] = action;
    });
  }

  Future<void> _finishExit(StagedFile file) async {
    final action = _pendingActions.remove(file.id);
    await action?.call();
    // Still here (the delete failed): bring the tile back.
    if (mounted && _exiting.contains(file.id)) {
      setState(() => _exiting.remove(file.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final files = w.files;
    final showAdd = _showAdd(w);
    final addVisible = showAdd || _addExiting;
    if (files.isEmpty && !addVisible) return const SizedBox.shrink();

    final c = context.sac;
    final totalFiles = files.length;
    final excess = totalFiles - w.maxFiles;
    final remoteImageFiles = files
        .where(
          (file) => file.isRemote && file.isImage && file.remoteUrl != null,
        )
        .toList();
    final reduce = SacMotion.reduceMotionOf(context);
    final slots = _addExiting && !showAdd
        ? (files.length > _addSlot ? files.length : _addSlot + 1)
        : files.length + (showAdd ? 1 : 0);
    final rows = (slots + _columns - 1) ~/ _columns;

    // Two files can share an id in odd flows; keep every key unique.
    final seen = <String, int>{};
    String keyOf(StagedFile f) {
      final n = seen.update(f.id, (v) => v + 1, ifAbsent: () => 0);
      return n == 0 ? f.id : '${f.id}#$n';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cellW = (width - _spacing * (_columns - 1)) / _columns;
            final cellH = cellW / _aspect;
            final height = rows * cellH + (rows - 1) * _spacing;
            Offset at(int slot) => Offset(
                  (slot % _columns) * (cellW + _spacing),
                  (slot ~/ _columns) * (cellH + _spacing),
                );

            Widget place(String key, int slot, Widget child) {
              final o = at(slot);
              return AnimatedPositioned(
                key: ValueKey('tile-$key'),
                duration: reduce ? Duration.zero : SacMotion.standard,
                curve: SacMotion.easeOut,
                left: o.dx,
                top: o.dy,
                width: cellW,
                height: cellH,
                child: child,
              );
            }

            return AnimatedSize(
              duration: reduce ? Duration.zero : SacMotion.standard,
              curve: SacMotion.easeOut,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = 0; index < files.length; index++)
                      () {
                        final file = files[index];
                        final key = keyOf(file);
                        // A local file is "excess" if its position is beyond
                        // maxFiles
                        final isExcess = file.isLocal && index >= w.maxFiles;
                        return place(
                          key,
                          index,
                          _TileMotion(
                            animateIn: _enterIds.contains(file.id),
                            exiting: _exiting.contains(file.id),
                            onExited: () => _finishExit(file),
                            child: _StagedFileCell(
                              file: file,
                              remoteImageFiles: remoteImageFiles,
                              isExcess: isExcess,
                              canModify: w.canModify,
                              onRemoveLocal: () => _beginExit(
                                file,
                                () => w.onRemoveLocal(file),
                              ),
                              onDeleteRemote: () => _confirmRemoteDelete(
                                context,
                                file,
                              ),
                            ),
                          ),
                        );
                      }(),
                    if (addVisible)
                      place(
                        'add',
                        showAdd ? files.length : _addSlot,
                        _TileMotion(
                          animateIn: false,
                          exiting: !showAdd,
                          onExited: () {
                            if (mounted) setState(() => _addExiting = false);
                          },
                          child: _AddTile(onTap: w.onAdd ?? () {}),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        // File counter (the add-tile layout shows it in the section title)
        if (w.showCounter)
          Center(
            child: Text(
              'core.evidence_staging.files_count'.tr(namedArgs: {
                'count': '$totalFiles',
                'max': '${w.maxFiles}',
              }),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
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
              (excess == 1
                      ? 'core.evidence_staging.excess_warning_one'
                      : 'core.evidence_staging.excess_warning_other')
                  .tr(namedArgs: {'count': '$excess'}),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Asks first; the tile only animates out once the user confirms.
  Future<void> _confirmRemoteDelete(
      BuildContext context, StagedFile file) async {
    final confirm = await SacDialog.show(
      context,
      title: tr('core.evidence_staging.delete_dialog_title'),
      content: tr(
        'core.evidence_staging.delete_dialog_body',
        namedArgs: {'name': file.name},
      ),
      confirmIsDestructive: true,
      cancelLabel: tr('core.evidence_staging.cancel'),
      confirmLabel: tr('core.evidence_staging.delete'),
    );

    if (confirm == true && mounted) {
      _beginExit(file, () => widget.onDeleteRemote(file));
    }
  }
}

/// Enter / exit of one tile: scale 0.96 <-> 1 plus fade. Enters when
/// [animateIn] is set on mount ([SacMotion.standard]); leaves when [exiting]
/// turns true ([SacMotion.press]) and then calls [onExited]. Back to false
/// brings it back. Reduced Motion keeps a short fade without the scale.
class _TileMotion extends StatefulWidget {
  const _TileMotion({
    required this.child,
    required this.animateIn,
    required this.exiting,
    required this.onExited,
  });

  final Widget child;
  final bool animateIn;
  final bool exiting;
  final VoidCallback onExited;

  @override
  State<_TileMotion> createState() => _TileMotionState();
}

class _TileMotionState extends State<_TileMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
      reverseDuration: SacMotion.press,
      value: widget.animateIn ? 0 : 1,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && widget.exiting && mounted) {
          widget.onExited();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = SacMotion.reduceMotionOf(context);
    _controller.duration = reduce ? SacMotion.reducedFade : SacMotion.standard;
    _controller.reverseDuration =
        reduce ? SacMotion.reducedFade : SacMotion.press;
    if (!_started) {
      _started = true;
      if (widget.animateIn) _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_TileMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting == oldWidget.exiting) return;
    if (widget.exiting) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return IgnorePointer(
      ignoring: widget.exiting,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final v = SacMotion.easeOut.transform(_controller.value);
          if (v >= 1) return child!;
          return Opacity(
            opacity: v,
            alwaysIncludeSemantics: true,
            child: Transform.scale(
              scale: reduce
                  ? 1
                  : SacMotion.enterScale + (1 - SacMotion.enterScale) * v,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

// ── Add tile ──────────────────────────────────────────────────────────────────

/// Last cell of the grid: dashed border, a plus and "Add".
class _AddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    final label = 'core.evidence_staging.add_tile'.tr();
    return Semantics(
      button: true,
      label: 'core.evidence_staging.add_tile_semantics'.tr(),
      excludeSemantics: true,
      onTap: onTap,
      child: SacPressable(
        key: const ValueKey('evidence-add-tile'),
        pressedScale: SacMotion.tilePressScale,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: accent.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          foregroundDecoration: _DashedBorderDecoration(
            color: accent.color,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            strokeWidth: 1.5,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 22,
                color: accent.color,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  fontWeight: FontWeight.w600,
                  color: accent.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades its child in and out (instead of popping) when [visible] changes.
class _FadePresence extends StatelessWidget {
  const _FadePresence({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return AnimatedSwitcher(
      duration: reduce ? SacMotion.reducedFade : SacMotion.standard,
      switchInCurve: SacMotion.easeOut,
      switchOutCurve: SacMotion.easeOut,
      child: visible
          ? KeyedSubtree(key: const ValueKey('on'), child: child)
          : const SizedBox.shrink(key: ValueKey('off')),
    );
  }
}

// ── Individual file cell ──────────────────────────────────────────────────────

class _StagedFileCell extends StatelessWidget {
  final StagedFile file;
  final List<StagedFile> remoteImageFiles;
  final bool isExcess;
  final bool canModify;
  final VoidCallback onRemoveLocal;
  final VoidCallback onDeleteRemote;

  const _StagedFileCell({
    required this.file,
    required this.remoteImageFiles,
    required this.isExcess,
    required this.canModify,
    required this.onRemoveLocal,
    required this.onDeleteRemote,
  });

  static DateFormat get _dateFormatter =>
      DateFormat('d MMM'); // getter: locale is captured at construction

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return GestureDetector(
      onTap: () => _openViewer(context),
      child: Stack(
        children: [
          // Main container
          Container(
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: file.isLocal
                  ? null // Dashed border handled by foregroundDecoration below
                  : Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            foregroundDecoration: file.isLocal
                ? _DashedBorderDecoration(
                    color: isExcess ? AppColors.error : AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    strokeWidth: 2,
                    dashWidth: 6,
                    dashGap: 4,
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail / icon
                Expanded(child: _buildThumbnail(context)),

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
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: SacFontSize.caption,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                            if (file.uploadedBy != null ||
                                file.uploadedAt != null)
                              Text(
                                [
                                  if (file.uploadedBy != null) file.uploadedBy!,
                                  if (file.uploadedAt != null)
                                    _dateFormatter.format(
                                      file.uploadedAt!.toLocal(),
                                    ),
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: SacFontSize.micro,
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
                            fontSize: SacFontSize.caption,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // ── Badges ────────────────────────────────────────────────────────

          // Local: "Nuevo" / "Extra" badge (top-right)
          Positioned(
            top: 4,
            right: 4,
            child: _FadePresence(
              visible: file.isLocal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isExcess ? AppColors.error : AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  isExcess
                      ? tr('core.evidence_staging.badge_extra')
                      : tr('core.evidence_staging.badge_new'),
                  style: const TextStyle(
                    fontSize: SacFontSize.micro,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // ── Delete buttons ────────────────────────────────────────────────

          // Local: instant remove. Remote: delete with confirmation.
          // The visible circle is 24pt; the tap area is 44pt.
          Positioned(
            top: 0,
            left: 0,
            child: _FadePresence(
              visible: canModify && (file.isLocal || file.isRemote),
              child: Semantics(
                button: true,
                label: tr('core.evidence_staging.remove_file'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: file.isLocal ? onRemoveLocal : onDeleteRemote,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: c.text.withValues(alpha: 0.62),
                          shape: BoxShape.circle,
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 14,
                          color: c.surface,
                        ),
                      ),
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

  Widget _buildThumbnail(BuildContext context) {
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
                fontSize: SacFontSize.caption,
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
        memCacheWidth: 360,
        memCacheHeight: 360,
        errorWidget: (_, __, ___) => _fallbackIcon(context),
        progressIndicatorBuilder: (context, url, downloadProgress) {
          return Container(
            color: SacAccent.of(context).light,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: downloadProgress.progress,
                color: SacAccent.of(context).color,
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
        cacheWidth: 360,
        cacheHeight: 360,
        errorBuilder: (_, __, ___) => _fallbackIcon(context),
      );
    }

    return _fallbackIcon(context);
  }

  Widget _fallbackIcon(BuildContext context) {
    return Container(
      color: SacAccent.of(context).light,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedImage01,
          size: 28,
          color: SacAccent.of(context).color,
        ),
      ),
    );
  }

  void _openViewer(BuildContext context) {
    if (file.isRemote && file.remoteUrl != null) {
      if (file.isImage) {
        final imageUrls =
            remoteImageFiles.map((file) => file.remoteUrl!).toList();
        final initialIndex =
            remoteImageFiles.indexWhere((imageFile) => imageFile.id == file.id);

        SacImageViewer.show(
          context,
          imageUrl: file.remoteUrl!,
          imageUrls: imageUrls,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        );
      } else if (file.isPdf) {
        SacPdfViewer.show(context,
            pdfSource: file.remoteUrl!, title: file.name);
      }
    } else if (file.isLocal && file.localPath != null && file.isImage) {
      // Local images: full-screen preview with InteractiveViewer
      Navigator.of(context).push(
        SacFadeThroughRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: SacTopBar(
              title: file.name,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: InteractiveViewer(
                child: Image.file(
                  File(file.localPath!),
                  fit: BoxFit.contain,
                  cacheWidth: 1600,
                ),
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
