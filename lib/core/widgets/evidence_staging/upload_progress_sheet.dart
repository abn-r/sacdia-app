import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../../animations/motion_tokens.dart';
import '../../theme/app_theme.dart';
import '../../theme/sac_accent.dart';
import '../../theme/sac_colors.dart';
import '../sac_button.dart';
import '../sac_dialog.dart';
import 'staged_file.dart';

/// Result returned from the upload progress sheet when it closes.
enum UploadSheetResult {
  /// All files uploaded successfully — proceed to submit.
  continueSubmit,

  /// User chose to continue with only the successfully uploaded files.
  continuePartial,

  /// User chose to retry only the failed files.
  retry,

  /// User cancelled — return to staging (already-uploaded files persist).
  cancelled,
}

/// Shows a persistent bottom sheet tracking upload progress for each file.
///
/// Returns an [UploadSheetResult] indicating the user's chosen action.
///
/// [files] is the list of files being uploaded (only local files in the queue).
/// [uploadStream] is a stream of updated file lists as uploads progress.
/// The caller must drive the upload queue and push updates to the stream.
Future<UploadSheetResult?> showUploadProgressSheet({
  required BuildContext context,
  required List<StagedFile> initialFiles,
  required Stream<List<StagedFile>> uploadStream,
}) {
  return showSacSheet<UploadSheetResult>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
    ),
    builder: (ctx) => _UploadProgressSheetContent(
      initialFiles: initialFiles,
      uploadStream: uploadStream,
    ),
  );
}

class _UploadProgressSheetContent extends StatefulWidget {
  final List<StagedFile> initialFiles;
  final Stream<List<StagedFile>> uploadStream;

  const _UploadProgressSheetContent({
    required this.initialFiles,
    required this.uploadStream,
  });

  @override
  State<_UploadProgressSheetContent> createState() =>
      _UploadProgressSheetContentState();
}

class _UploadProgressSheetContentState
    extends State<_UploadProgressSheetContent>
    with SingleTickerProviderStateMixin {
  late List<StagedFile> _files;
  late final StreamSubscription<List<StagedFile>> _subscription;

  /// The deck opens into a grid only when the user asks («Ver todos»).
  bool _showAll = false;
  bool _celebrated = false;

  /// Progress shown per file. It follows the real upload but never runs
  /// faster than [_minSweep] from 0 to 100%, so a small file that the server
  /// takes at once still visibly fills up. Nothing is invented: the shown
  /// value only catches up with what was reported.
  final Map<String, double> _shown = {};
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  static const Duration _minSweep = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.initialFiles);
    for (final f in _files) {
      // Files already done when the sheet opens start full.
      _shown[f.id] = f.status == StagedFileStatus.uploaded ||
              f.status == StagedFileStatus.completed
          ? 1
          : 0;
    }
    _ticker = createTicker(_onTick);
    // reduceMotion reads MediaQuery: wait for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker();
    });
    _subscription = widget.uploadStream.listen((updatedFiles) {
      if (!mounted) return;
      setState(() => _files = updatedFiles);
      _syncTicker();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _subscription.cancel();
    super.dispose();
  }

  double _target(StagedFile f) {
    switch (f.status) {
      case StagedFileStatus.completed:
      case StagedFileStatus.uploaded:
        return 1;
      case StagedFileStatus.uploading:
        return f.uploadProgress.clamp(0.0, 1.0);
      case StagedFileStatus.error:
        // Freeze where it stopped.
        return _shown[f.id] ?? 0;
      case StagedFileStatus.local:
        return 0;
    }
  }

  bool get _catchingUp =>
      _files.any((f) => (_shown[f.id] ?? 0) < _target(f) - 0.0001);

  void _syncTicker() {
    if (SacMotion.reduceMotionOf(context)) {
      setState(() {
        for (final f in _files) {
          _shown[f.id] = _target(f);
        }
      });
      _checkCelebration();
      return;
    }
    if (_catchingUp && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    _checkCelebration();
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    final step = dt.inMicroseconds / _minSweep.inMicroseconds;
    setState(() {
      for (final f in _files) {
        final current = _shown[f.id] ?? 0;
        final target = _target(f);
        if (current < target) {
          _shown[f.id] = math.min(target, current + step);
        }
      }
    });
    if (!_catchingUp) {
      _ticker.stop();
      _checkCelebration();
    }
  }

  void _checkCelebration() {
    if (_allSuccess && !_celebrated) {
      _celebrated = true;
      HapticFeedback.mediumImpact();
    }
  }

  /// The files as the user sees them: a file reads as completed only once
  /// its bar has visibly reached 100%.
  List<StagedFile> get _visible => [
        for (final f in _files)
          switch (f.status) {
            StagedFileStatus.uploading ||
            StagedFileStatus.completed when (_shown[f.id] ?? 0) < 1 =>
              f.copyWith(
                status: StagedFileStatus.uploading,
                uploadProgress: _shown[f.id] ?? 0,
              ),
            _ => f,
          },
      ];

  // ── Computed state ──────────────────────────────────────────────────────────

  int _count(StagedFileStatus status) =>
      _visible.where((f) => f.status == status).length;
  int get _completedCount => _count(StagedFileStatus.completed);
  int get _errorCount => _count(StagedFileStatus.error);
  int get _uploadingCount => _count(StagedFileStatus.uploading);
  int get _pendingCount => _count(StagedFileStatus.local);

  bool get _isInProgress => _uploadingCount > 0 || _pendingCount > 0;
  bool get _allDone => !_isInProgress;
  bool get _allSuccess => _allDone && _errorCount == 0;
  bool get _hasErrors => _allDone && _errorCount > 0;
  bool get _allFailed => _allDone && _completedCount == 0 && _errorCount > 0;

  double get _overallProgress {
    if (_files.isEmpty) return 0;
    final sum = _files.fold<double>(
      0,
      (total, f) =>
          total +
          (f.status == StagedFileStatus.error ? 0 : (_shown[f.id] ?? 0)),
    );
    return sum / _files.length;
  }

  /// The file on top of the deck: the one uploading, else the first failure,
  /// else the next in line, else the last one.
  int get _focusIndex {
    final files = _visible;
    if (files.isEmpty) return 0;
    for (final status in [
      StagedFileStatus.uploading,
      StagedFileStatus.error,
      StagedFileStatus.local,
    ]) {
      final index = files.indexWhere((f) => f.status == status);
      if (index >= 0) return index;
    }
    return files.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final visible = _visible;
    final focus = visible.isEmpty ? null : visible[_focusIndex];
    final canExpand = _allDone && _files.length > 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SacSheetGrabber(padded: false),
                const SizedBox(height: 18),
                _buildHeader(c),
                const SizedBox(height: 18),
                _FileDeck(
                  files: visible,
                  focusIndex: _focusIndex,
                  expanded: _showAll && canExpand,
                  done: _allSuccess,
                ),
                if (!(_showAll && canExpand) && focus != null)
                  _FocusCaption(file: focus, done: _allSuccess),
                const SizedBox(height: 16),
                _AnimatedOverallProgress(
                  progress: _overallProgress,
                  color: _hasErrors
                      ? c.warning
                      : _allSuccess
                          ? c.success
                          : SacAccent.of(context).color,
                  backgroundColor: c.surfaceVariant,
                ),
                if (canExpand) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      key: const ValueKey('upload-toggle-view'),
                      onPressed: () => setState(() => _showAll = !_showAll),
                      icon: HugeIcon(
                        icon: _showAll
                            ? HugeIcons.strokeRoundedLayers01
                            : HugeIcons.strokeRoundedGridView,
                        size: 18,
                        color: SacAccent.of(context).color,
                      ),
                      label: Text(
                        _showAll
                            ? tr('core.evidence_staging.show_stack')
                            : tr(
                                'core.evidence_staging.show_all',
                                namedArgs: {'count': '${_files.length}'},
                              ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: SacAccent.of(context).color,
                        minimumSize: const Size(44, 44),
                        textStyle: const TextStyle(
                          fontSize: SacFontSize.titleSmall,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (_allDone) _buildActionButtons(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SacColors c) {
    final String title;
    final String? body;
    Color titleColor = c.text;
    if (_isInProgress) {
      title = tr(
        'core.evidence_staging.uploading_title',
        namedArgs: {
          'current': '${math.min(_completedCount + 1, _files.length)}',
          'total': '${_files.length}',
        },
      );
      body = tr('core.evidence_staging.uploading_hint');
    } else if (_allSuccess) {
      title = 'core.evidence_staging.done_title'.plural(_completedCount);
      body = tr('core.evidence_staging.done_body');
    } else if (_allFailed) {
      title = tr('core.evidence_staging.upload_all_failed');
      body = tr('core.evidence_staging.failed_body');
      titleColor = c.onErrorContainer;
    } else {
      title = 'core.evidence_staging.partial_title'.plural(_errorCount);
      body = tr('core.evidence_staging.partial_body');
      titleColor = c.onWarningContainer;
    }

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: SacFontSize.headlineSmall,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            height: 1.4,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(SacColors c) {
    if (_allSuccess) {
      return SacButton.primary(
        text: tr('core.evidence_staging.btn_continue'),
        onPressed: () =>
            Navigator.pop(context, UploadSheetResult.continueSubmit),
      );
    }

    // Partial failure or all failed: retry first, then the way out.
    return Column(
      children: [
        SacButton.primary(
          text: tr('core.evidence_staging.btn_retry_failed',
              namedArgs: {'count': '$_errorCount'}),
          onPressed: () => Navigator.pop(context, UploadSheetResult.retry),
        ),
        if (!_allFailed) ...[
          const SizedBox(height: 8),
          SacButton.outline(
            text: tr('core.evidence_staging.btn_continue_partial',
                namedArgs: {'count': '$_completedCount'}),
            onPressed: () => _confirmContinuePartial(context),
          ),
        ],
        const SizedBox(height: 8),
        SacButton(
          text: tr('core.evidence_staging.cancel'),
          variant: SacButtonVariant.ghost,
          fullWidth: true,
          textColor: c.textSecondary,
          onPressed: () => Navigator.pop(context, UploadSheetResult.cancelled),
        ),
      ],
    );
  }

  Future<void> _confirmContinuePartial(BuildContext ctx) async {
    final c = ctx.sac;
    final confirm = await SacDialog.show(
      ctx,
      title: tr('core.evidence_staging.partial_dialog_title'),
      content: 'core.evidence_staging.partial_dialog_body'.plural(
        _errorCount,
        name: 'count',
      ),
      icon: HugeIcons.strokeRoundedAlert02,
      iconColor: c.onWarningContainer,
      iconBackgroundColor: c.warningContainer,
      cancelLabel: tr('core.evidence_staging.cancel'),
      confirmLabel: tr('core.evidence_staging.btn_continue'),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context, UploadSheetResult.continuePartial);
    }
  }
}

// ── Deck: stacked by default, a grid on demand ────────────────────────────────

/// Every file as a card. Collapsed, the focused file sits on top of a small
/// pile (option A: one file at a time). Expanded, the same cards fly to their
/// place in a three-column grid. Each card animates its own position, size
/// and tilt, so the switch reads as the pile opening up.
class _FileDeck extends StatelessWidget {
  const _FileDeck({
    required this.files,
    required this.focusIndex,
    required this.expanded,
    required this.done,
  });

  final List<StagedFile> files;
  final int focusIndex;
  final bool expanded;
  final bool done;

  static const double _focusSize = 156;
  static const double _backSize = 140;
  static const double _collapsedHeight = 176;
  static const double _gap = 8;
  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final duration = reduce ? Duration.zero : SacMotion.modal * 1.5;
    const curve = SacMotion.drawer;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cell = (width - _gap * (_columns - 1)) / _columns;
        final rows = (files.length / _columns).ceil();
        final gridHeight = rows * cell + (rows - 1) * _gap;
        final height = expanded ? gridHeight : _collapsedHeight;

        // Up to two cards peek out behind the focused one: the ones just
        // before it (already handled), else the ones after it.
        final behind = <int>[
          for (var i = focusIndex - 1; i >= 0 && i >= focusIndex - 2; i--) i,
        ];
        for (var i = focusIndex + 1;
            behind.length < 2 && i < files.length;
            i++) {
          behind.add(i);
        }

        // Paint order: hidden cards, then the pile, then the focus on top.
        final order = [
          for (var i = 0; i < files.length; i++)
            if (i != focusIndex && !behind.contains(i)) i,
          ...behind.reversed,
          focusIndex,
        ];

        Rect collapsedRect(int index) {
          final center = width / 2;
          if (index == focusIndex) {
            return Rect.fromLTWH(
                center - _focusSize / 2, 8, _focusSize, _focusSize);
          }
          final slot = behind.indexOf(index);
          final dx = slot == 0 ? -22.0 : 22.0;
          return Rect.fromLTWH(
            center - _backSize / 2 + (slot < 0 ? 0 : dx),
            14,
            _backSize,
            _backSize,
          );
        }

        Rect gridRect(int index) {
          final col = index % _columns;
          final row = index ~/ _columns;
          return Rect.fromLTWH(
            col * (cell + _gap),
            row * (cell + _gap),
            cell,
            cell,
          );
        }

        double tilt(int index) {
          if (expanded || index == focusIndex) return 0;
          final slot = behind.indexOf(index);
          if (slot < 0) return 0;
          return slot == 0 ? -0.07 : 0.06;
        }

        double opacity(int index) {
          if (expanded || index == focusIndex) return 1;
          return behind.contains(index) ? 0.7 : 0;
        }

        return AnimatedContainer(
          key: const ValueKey('upload-file-deck'),
          duration: duration,
          curve: curve,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in order)
                AnimatedPositioned.fromRect(
                  key: ValueKey('upload-card-${files[i].id}'),
                  duration: duration,
                  curve: curve,
                  rect: expanded ? gridRect(i) : collapsedRect(i),
                  child: AnimatedRotation(
                    turns: tilt(i) / (2 * math.pi),
                    duration: duration,
                    curve: curve,
                    child: AnimatedOpacity(
                      opacity: opacity(i),
                      duration: duration,
                      curve: curve,
                      child: _FileCard(
                        file: files[i],
                        showProgress: expanded || i == focusIndex,
                        celebrate: done && !expanded && i == focusIndex,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One file: its real thumbnail (or a PDF tile) with its state on top.
/// Waiting files are faded; the one uploading clears from the bottom up as
/// its bytes go out.
class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.showProgress,
    required this.celebrate,
  });

  final StagedFile file;
  final bool showProgress;
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final path = file.localPath;
    final Widget preview = file.isImage && path != null
        ? Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: 420,
            errorBuilder: (_, __, ___) => _PlaceholderTile(file: file),
          )
        : _PlaceholderTile(file: file);

    return Semantics(
      label: '${file.name}, ${_statusLabel(file)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview,
              if (file.status == StagedFileStatus.local)
                ColoredBox(color: c.surface.withValues(alpha: 0.55)),
              if (file.status == StagedFileStatus.uploading)
                _UploadVeil(file: file, showBadge: showProgress),
              if (file.status == StagedFileStatus.error)
                ColoredBox(
                  color: c.error.withValues(alpha: 0.55),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      size: 26,
                      color: c.onError,
                    ),
                  ),
                ),
              if (file.status == StagedFileStatus.completed ||
                  file.status == StagedFileStatus.uploaded)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: AnimatedContainer(
                    duration: SacMotion.standard,
                    curve: SacMotion.easeOut,
                    width: celebrate ? 30 : 20,
                    height: celebrate ? 30 : 20,
                    decoration: BoxDecoration(
                      color: c.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 2),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      size: celebrate ? 18 : 12,
                      color: c.onSuccess,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(StagedFile file) {
    switch (file.status) {
      case StagedFileStatus.local:
        return tr('core.evidence_staging.waiting');
      case StagedFileStatus.uploading:
        return '${(file.uploadProgress * 100).round()}%';
      case StagedFileStatus.error:
        return file.errorMessage ?? tr('core.evidence_staging.upload_failed');
      case StagedFileStatus.completed:
      case StagedFileStatus.uploaded:
        return tr('core.evidence_staging.uploaded');
    }
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.file});

  final StagedFile file;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ColoredBox(
      color: file.isPdf ? c.errorContainer : c.surfaceVariant,
      child: Center(
        child: HugeIcon(
          icon: file.isPdf
              ? HugeIcons.strokeRoundedPdf01
              : HugeIcons.strokeRoundedImage01,
          size: 32,
          color: file.isPdf ? c.onErrorContainer : c.textTertiary,
        ),
      ),
    );
  }
}

/// Covers the part not sent yet: the photo clears from the bottom up.
class _UploadVeil extends StatelessWidget {
  const _UploadVeil({required this.file, required this.showBadge});

  final StagedFile file;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final value = file.uploadProgress.clamp(0.0, 1.0);
    // All bytes are out but the server has not answered yet.
    final saving = value >= 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 1 - value,
            widthFactor: 1,
            child: ColoredBox(color: c.surface.withValues(alpha: 0.55)),
          ),
        ),
        if (showBadge)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 4, 8, 4),
              decoration: BoxDecoration(
                color: c.text.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      key: ValueKey('upload-file-progress-${file.id}'),
                      value: saving ? null : value,
                      strokeWidth: 2,
                      color: c.surface,
                      backgroundColor: c.surface.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    saving
                        ? tr('core.evidence_staging.saving')
                        : '${(value * 100).round()}%',
                    key: ValueKey('upload-file-progress-value-${file.id}'),
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      fontWeight: FontWeight.w700,
                      color: c.surface,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Name of the file on top, and why it failed when it did.
class _FocusCaption extends StatelessWidget {
  const _FocusCaption({required this.file, required this.done});

  final StagedFile file;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final failed = file.status == StagedFileStatus.error;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          if (failed && (file.errorMessage?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 2),
            Text(
              file.errorMessage!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                height: 1.3,
                color: c.onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimatedOverallProgress extends StatelessWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const _AnimatedOverallProgress({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final animatedProgress = progress.clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              key: const ValueKey('upload-overall-progress-bar'),
              value: animatedProgress,
              minHeight: 6,
              backgroundColor: backgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            '${(animatedProgress * 100).round()}%',
            key: const ValueKey('upload-overall-progress-value'),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w700,
              color: c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
