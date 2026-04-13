import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../theme/app_colors.dart';
import '../../theme/sac_colors.dart';
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
  return showModalBottomSheet<UploadSheetResult>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    extends State<_UploadProgressSheetContent> {
  late List<StagedFile> _files;
  late final StreamSubscription<List<StagedFile>> _subscription;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.initialFiles);
    _subscription = widget.uploadStream.listen((updatedFiles) {
      if (mounted) {
        setState(() => _files = updatedFiles);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // ── Computed state ──────────────────────────────────────────────────────────

  int get _completedCount =>
      _files.where((f) => f.status == StagedFileStatus.completed).length;
  int get _errorCount =>
      _files.where((f) => f.status == StagedFileStatus.error).length;
  int get _uploadingCount =>
      _files.where((f) => f.status == StagedFileStatus.uploading).length;
  int get _pendingCount =>
      _files.where((f) => f.status == StagedFileStatus.local).length;

  bool get _isInProgress => _uploadingCount > 0 || _pendingCount > 0;
  bool get _allDone => !_isInProgress;
  bool get _allSuccess => _allDone && _errorCount == 0;
  bool get _hasErrors => _allDone && _errorCount > 0;
  bool get _allFailed => _allDone && _completedCount == 0 && _errorCount > 0;

  double get _overallProgress {
    if (_files.isEmpty) return 0;
    final total = _files.length.toDouble();
    final completed = _completedCount.toDouble();
    // Add partial progress from the currently uploading file
    final uploading = _files.where((f) => f.status == StagedFileStatus.uploading);
    final partialProgress =
        uploading.fold<double>(0, (sum, f) => sum + f.uploadProgress);
    return (completed + partialProgress) / total;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            _buildHeader(c),
            const SizedBox(height: 12),

            // Overall progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _overallProgress,
                minHeight: 6,
                backgroundColor: c.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _hasErrors
                      ? AppColors.accent
                      : _allSuccess
                          ? AppColors.secondary
                          : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // File list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: ListView.separated(
                // shrinkWrap removed: ConstrainedBox(maxHeight) provides a
                // bounded height constraint — ListView can scroll normally.
                itemCount: _files.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: c.divider,
                ),
                itemBuilder: (context, index) =>
                    _FileProgressRow(file: _files[index]),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            if (_allDone) _buildActionButtons(c),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(SacColors c) {
    if (_isInProgress) {
      return Text(
        'Subiendo ${_completedCount + 1} de ${_files.length} archivos...',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: c.text,
        ),
      );
    }
    if (_allSuccess) {
      return const Text(
        'Todos los archivos subidos',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.secondary,
        ),
      );
    }
    if (_allFailed) {
      return const Text(
        'Todos los archivos fallaron',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.error,
        ),
      );
    }
    // Partial failure
    return Text(
      '$_completedCount de ${_files.length} subidos, $_errorCount fallaron',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.accentDark,
      ),
    );
  }

  Widget _buildActionButtons(SacColors c) {
    if (_allSuccess) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () =>
              Navigator.pop(context, UploadSheetResult.continueSubmit),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Continuar',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Partial failure or all failed: 3 buttons
    return Column(
      children: [
        // Retry failed — returns UploadSheetResult.retry so the manager
        // can re-run uploads for only the failed files.
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () =>
                Navigator.pop(context, UploadSheetResult.retry),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Reintentar fallidos ($_errorCount)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),

        // Continue with uploaded (only if some succeeded)
        if (!_allFailed) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmContinuePartial(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppColors.secondary, width: 1.5),
              ),
              child: Text(
                'Continuar con los subidos ($_completedCount)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
        ],

        // Cancel
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () =>
                Navigator.pop(context, UploadSheetResult.cancelled),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: c.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmContinuePartial(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Continuar sin todos los archivos'),
        content: Text(
          'Los $_errorCount archivos que fallaron no se incluirán en la validación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context, UploadSheetResult.continuePartial);
    }
  }
}

// ── Individual file row ────────────────────────────────────────────────────────

class _FileProgressRow extends StatelessWidget {
  final StagedFile file;

  const _FileProgressRow({required this.file});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // File type icon
          HugeIcon(
            icon: file.isImage
                ? HugeIcons.strokeRoundedImage01
                : HugeIcons.strokeRoundedPdf01,
            size: 20,
            color: file.isImage ? AppColors.primary : AppColors.error,
          ),
          const SizedBox(width: 10),

          // File name
          Expanded(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Status indicator
          _buildStatusIndicator(c),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(SacColors c) {
    switch (file.status) {
      case StagedFileStatus.local:
        // Pending: yellow dot
        return Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        );

      case StagedFileStatus.uploading:
        // Uploading: blue dot + percentage
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.sacBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(file.uploadProgress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.sacBlue,
              ),
            ),
          ],
        );

      case StagedFileStatus.completed:
        // Completed: green check
        return const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppColors.secondary,
        );

      case StagedFileStatus.error:
        // Error: red X
        return const Icon(
          Icons.error_rounded,
          size: 18,
          color: AppColors.error,
        );

      case StagedFileStatus.uploaded:
        // Should not appear in upload sheet, but handle gracefully
        return const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppColors.secondary,
        );
    }
  }
}
