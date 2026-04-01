import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';
import '../../theme/sac_colors.dart';
import '../../utils/app_logger.dart';
import '../sac_button.dart';
import 'image_source_dialog.dart';
import 'staged_file.dart';
import 'staged_file_grid.dart';
import 'upload_progress_sheet.dart';

/// Main orchestrator widget for evidence file staging.
///
/// Consumed by both `RequirementDetailView` (classes) and
/// `EvidenceSectionDetailView` (evidence folders). Each integration point
/// maps its domain entities to [StagedFile] before passing them in.
///
/// Internal state is managed via `StatefulWidget` + `setState`.
/// Riverpod notifiers are used only in the parent screens.
class EvidenceStagingManager extends StatefulWidget {
  /// Already-uploaded files — the caller maps domain entities to
  /// `StagedFile(status: uploaded)` before passing them here.
  final List<StagedFile> existingFiles;

  /// Maximum number of files allowed (remote + local combined).
  final int maxFiles;

  /// Callback to upload a single file. Receives an [XFile], its mime type,
  /// and an `onProgress` callback that the caller should wire to Dio's
  /// `onSendProgress` to report upload progress (0.0 to 1.0).
  final Future<void> Function(
    XFile file,
    String mimeType,
    void Function(double progress) onProgress,
  ) onUpload;

  /// Callback to delete an already-uploaded file from the server.
  final Future<void> Function(String fileId) onDeleteRemote;

  /// Callback to mark the requirement/section as submitted for validation.
  final Future<void> Function() onSubmit;

  /// Builds a descriptive file name for backend/storage.
  /// [originalName] is the picked file's name, [index] is the absolute
  /// position in the full file list (remote count + local position), 1-based.
  final String Function(String originalName, int index) fileNameBuilder;

  /// False when the requirement/section status is not `pendiente`.
  /// Disables all modification controls.
  final bool canModify;

  /// Whether the notifier is currently loading (submit, delete, etc.).
  /// Used to disable the action bar while operations are in progress.
  final bool isLoading;

  /// Called whenever the count of local (unsaved) files changes.
  /// The parent can use this to update `PopScope.canPop` without a GlobalKey.
  final void Function(bool hasLocalFiles)? onLocalFilesChanged;

  /// When true, the widget renders WITHOUT its own [Expanded] /
  /// [SingleChildScrollView] wrapper and WITHOUT the action bar.
  ///
  /// Use this when embedding the staging manager inside a parent scroll view.
  /// The parent is responsible for providing scrolling and for placing the
  /// action bar (via [buildActionBar]) wherever it belongs in the layout.
  ///
  /// Defaults to false for backward compatibility.
  final bool embeddedMode;

  const EvidenceStagingManager({
    super.key,
    required this.existingFiles,
    required this.maxFiles,
    required this.onUpload,
    required this.onDeleteRemote,
    required this.onSubmit,
    required this.fileNameBuilder,
    required this.canModify,
    this.isLoading = false,
    this.onLocalFilesChanged,
    this.embeddedMode = false,
  });

  @override
  State<EvidenceStagingManager> createState() => EvidenceStagingManagerState();
}

class EvidenceStagingManagerState extends State<EvidenceStagingManager> {
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  final _picker = ImagePicker();

  /// Combined list: remote files first, then locally staged files.
  late List<StagedFile> _allFiles;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _allFiles = List.from(widget.existingFiles);
  }

  @override
  void didUpdateWidget(covariant EvidenceStagingManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When parent rebuilds with new existing files (e.g. after provider
    // invalidation), merge them with any remaining local files.
    if (oldWidget.existingFiles != widget.existingFiles) {
      final localFiles = _allFiles.where((f) => f.isLocal).toList();
      _allFiles = [...widget.existingFiles, ...localFiles];
    }
  }

  // ── Computed ────────────────────────────────────────────────────────────────

  List<StagedFile> get _localFiles =>
      _allFiles.where((f) => f.isLocal).toList();

  bool get _hasLocalFiles => _localFiles.isNotEmpty;

  bool get _hasAnyFiles => _allFiles.isNotEmpty;

  bool get _isOverLimit => _allFiles.length > widget.maxFiles;

  /// Whether the "Enviar" button should be enabled.
  bool get _canSubmit =>
      widget.canModify && !_isUploading && _hasAnyFiles && !_isOverLimit;

  /// Notifies the parent whenever the local file count changes.
  /// Used for PopScope without GlobalKey (I-2 fix).
  void _notifyLocalFilesChanged() {
    widget.onLocalFilesChanged?.call(_hasLocalFiles);
  }

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _pickImages(BuildContext context) async {
    final source = await showImageSourceDialog(context);
    if (source == null || !mounted) return;

    try {
      final List<XFile> pickedFiles;
      if (source == ImageSource.camera) {
        final single = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        pickedFiles = single != null ? [single] : [];
      } else {
        pickedFiles = await _picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
      }

      if (pickedFiles.isEmpty || !mounted) return;

      // Validate file sizes before staging.
      final validFiles = <XFile>[];
      int skippedCount = 0;
      for (final picked in pickedFiles) {
        final size = await picked.length();
        if (size > _maxFileSizeBytes) {
          skippedCount++;
        } else {
          validFiles.add(picked);
        }
      }

      if (skippedCount > 0 && mounted) {
        _showErrorSnackbar(
          context, // ignore: use_build_context_synchronously
          '$skippedCount ${skippedCount == 1 ? 'imagen excede' : 'imágenes exceden'} el límite de 10 MB y no se agregó.',
        );
      }

      if (validFiles.isEmpty || !mounted) return;

      // I-3: Never mutate _allFiles in place — always create a new list.
      setState(() {
        final newFiles = validFiles.map((picked) {
          final mimeType = picked.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          return StagedFile.local(
            localPath: picked.path,
            name: picked.name,
            mimeType: mimeType,
          );
        }).toList();
        _allFiles = [..._allFiles, ...newFiles];
      });
      _notifyLocalFilesChanged();
    } catch (e) {
      AppLogger.e('Error al seleccionar imagen', error: e);
      if (mounted) {
        // ignore: use_build_context_synchronously
        _showErrorSnackbar(context, 'No se pudo seleccionar la imagen.');
      }
    }
  }

  Future<void> _pickPdfs(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      // Validate file sizes before staging.
      final validPdfs =
          result.files.where((pf) => pf.path != null).toList();
      final oversized = validPdfs.where((pf) => pf.size > _maxFileSizeBytes);
      final acceptedPdfs =
          validPdfs.where((pf) => pf.size <= _maxFileSizeBytes).toList();

      if (oversized.isNotEmpty && mounted) {
        final count = oversized.length;
        _showErrorSnackbar(
          context, // ignore: use_build_context_synchronously
          '$count ${count == 1 ? 'PDF excede' : 'PDFs exceden'} el límite de 10 MB y no se agregó.',
        );
      }

      if (acceptedPdfs.isEmpty || !mounted) return;

      // I-3: Never mutate _allFiles in place — always create a new list.
      setState(() {
        final newFiles = acceptedPdfs
            .map((pf) => StagedFile.local(
                  localPath: pf.path!,
                  name: pf.name,
                  mimeType: 'application/pdf',
                ))
            .toList();
        _allFiles = [..._allFiles, ...newFiles];
      });
      _notifyLocalFilesChanged();
    } catch (e) {
      AppLogger.e('Error al seleccionar PDF', error: e);
      if (mounted) {
        // ignore: use_build_context_synchronously
        _showErrorSnackbar(context, 'No se pudo seleccionar el PDF.');
      }
    }
  }

  // ── Local file removal ──────────────────────────────────────────────────────

  // I-3: Never mutate _allFiles in place — always create a new list.
  void _removeLocalFile(StagedFile file) {
    setState(() {
      _allFiles = _allFiles.where((f) => f.id != file.id).toList();
    });
    _notifyLocalFilesChanged();
  }

  // ── Remote file deletion ──────────────────────────────────────────────────

  // I-3: Never mutate _allFiles in place — always create a new list.
  Future<void> _deleteRemoteFile(StagedFile file) async {
    try {
      await widget.onDeleteRemote(file.id);
      if (mounted) {
        setState(() {
          _allFiles = _allFiles.where((f) => f.id != file.id).toList();
        });
      }
    } catch (e) {
      AppLogger.e('Error al eliminar archivo', error: e);
      if (mounted) {
        _showErrorSnackbar(context, 'No se pudo eliminar el archivo.');
      }
    }
  }

  // ── Upload + Submit flow ──────────────────────────────────────────────────

  Future<void> _submitForValidation(BuildContext context) async {
    // If no local files, skip upload and go straight to submit
    if (!_hasLocalFiles) {
      await _confirmAndSubmit(context);
      return;
    }

    // If over limit, block
    if (_isOverLimit) {
      _showErrorSnackbar(
        context,
        'Tienes archivos de más. Eliminá algunos para continuar.',
      );
      return;
    }

    // Confirm intent
    final confirm = await _showSubmitConfirmDialog(context);
    if (!confirm || !mounted) return;

    // Execute upload queue with progress sheet
    // ignore: use_build_context_synchronously
    await _executeUploadQueue(context);
  }

  Future<void> _executeUploadQueue(BuildContext context) async {
    setState(() => _isUploading = true);

    // Prepare the upload stream controller
    final streamController = StreamController<List<StagedFile>>.broadcast();

    // Assign file names with proper indexes
    final remoteCount =
        _allFiles.where((f) => f.status == StagedFileStatus.uploaded).length;
    final localFiles = _localFiles;

    // Show the progress sheet
    final sheetResultFuture = showUploadProgressSheet(
      context: context,
      initialFiles: localFiles,
      uploadStream: streamController.stream,
    );

    // Execute uploads sequentially
    for (int i = 0; i < localFiles.length; i++) {
      final file = localFiles[i];
      final fileIndex = remoteCount + i + 1;
      final fileName = widget.fileNameBuilder(file.name, fileIndex);

      // Transition to uploading
      _updateFileStatus(
        file.id,
        StagedFileStatus.uploading,
        uploadProgress: 0.0,
      );
      streamController.add(_localFiles);

      try {
        final xFile = XFile(
          file.localPath!,
          name: fileName,
          mimeType: file.mimeType,
        );

        await widget.onUpload(
          xFile,
          file.mimeType ?? 'application/octet-stream',
          (progress) {
            _updateFileStatus(
              file.id,
              StagedFileStatus.uploading,
              uploadProgress: progress,
            );
            streamController.add(_localFiles);
          },
        );

        // Success
        _updateFileStatus(file.id, StagedFileStatus.completed);
        streamController.add(_localFiles);
      } catch (e) {
        AppLogger.e('Error uploading file: ${file.name}', error: e);
        _updateFileStatus(
          file.id,
          StagedFileStatus.error,
          errorMessage: e.toString(),
        );
        streamController.add(_localFiles);
      }
    }

    // Wait for user action on the sheet
    final sheetResult = await sheetResultFuture;
    await streamController.close();

    if (!mounted) return;

    setState(() => _isUploading = false);

    // I-3: Never mutate _allFiles in place — always create a new list.
    switch (sheetResult) {
      case UploadSheetResult.continueSubmit:
      case UploadSheetResult.continuePartial:
        // Remove local files that were completed (they're now on server)
        setState(() {
          _allFiles = _allFiles.where((f) {
            if (f.status == StagedFileStatus.completed) return false;
            if (sheetResult == UploadSheetResult.continuePartial &&
                f.status == StagedFileStatus.error) {
              return false;
            }
            return true;
          }).toList();
        });
        // Proceed to submit
        await widget.onSubmit();
        break;

      // C-3: Retry actually re-runs the upload loop for failed files.
      case UploadSheetResult.retry:
        // Reset failed files back to uploading and re-run the loop
        setState(() {
          _allFiles = _allFiles.map((f) {
            if (f.status == StagedFileStatus.error) {
              return f.copyWith(
                status: StagedFileStatus.local,
                uploadProgress: 0.0,
                errorMessage: null,
              );
            }
            return f;
          }).toList();
        });
        // Recursively re-run the upload queue for the remaining local files
        if (_hasLocalFiles && mounted) {
          // ignore: use_build_context_synchronously
          await _executeUploadQueue(context);
        }
        break;

      case UploadSheetResult.cancelled:
        // Return failed files to local status for manual re-staging
        setState(() {
          _allFiles = _allFiles.map((f) {
            if (f.status == StagedFileStatus.error) {
              return f.copyWith(
                status: StagedFileStatus.local,
                uploadProgress: 0.0,
                errorMessage: null,
              );
            }
            if (f.status == StagedFileStatus.completed) {
              // Already uploaded — will appear as remote on next refresh
              return f;
            }
            return f;
          }).toList();
        });
        break;

      case null:
        break;
    }
  }

  /// Updates a file's status in the list. Creates a new list (I-3).
  ///
  /// With the sentinel copyWith pattern (I-1), passing `null` for
  /// [errorMessage] explicitly clears it, while omitting it preserves
  /// the existing value. Here we always pass it through since every
  /// status transition has clear intent:
  /// - `uploading` / `completed`: errorMessage is null -> clears previous error
  /// - `error`: errorMessage is set -> stores the error
  void _updateFileStatus(
    String fileId,
    StagedFileStatus status, {
    double? uploadProgress,
    String? errorMessage,
  }) {
    setState(() {
      _allFiles = _allFiles.map((f) {
        if (f.id == fileId) {
          return f.copyWith(
            status: status,
            uploadProgress: uploadProgress ?? f.uploadProgress,
            errorMessage: errorMessage,
          );
        }
        return f;
      }).toList();
    });
    _notifyLocalFilesChanged();
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  Future<void> _confirmAndSubmit(BuildContext context) async {
    final confirm = await _showSubmitConfirmDialog(context);
    if (!confirm || !mounted) return;
    await widget.onSubmit();
  }

  Future<bool> _showSubmitConfirmDialog(BuildContext context) async {
    final totalFiles = _allFiles.length;
    final newFiles = _localFiles.length;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar a validación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Una vez enviado, no podrás modificar los archivos hasta recibir retroalimentación.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Archivos totales: $totalFiles'
              '${newFiles > 0 ? ' ($newFiles nuevos por subir)' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  // I-2: The action bar is built directly inside this widget's build method,
  // eliminating the need for a GlobalKey<EvidenceStagingManagerState> in the
  // parent. The parent Scaffold should NOT use bottomNavigationBar — instead,
  // this widget outputs both the grid and the action bar in a single Column.
  // I-5: No mid-batch invalidation issue since C-2 (skipInvalidation) ensures
  // providers are not invalidated during batch uploads. A single invalidation
  // happens after the full batch via the onSubmit callback.

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _allFiles.isEmpty
          ? _EmptyFiles(canModify: widget.canModify)
          : StagedFileGrid(
              files: _allFiles,
              maxFiles: widget.maxFiles,
              canModify: widget.canModify,
              onRemoveLocal: _removeLocalFile,
              onDeleteRemote: _deleteRemoteFile,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Embedded mode: no Expanded, no SingleChildScrollView.
    // The parent provides scrolling via its own SingleChildScrollView.
    // The action bar is included at the bottom of the Column so it remains
    // co-located with the content — the user scrolls down to reach it.
    if (widget.embeddedMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildContent(),
          if (widget.canModify)
            _EvidenceStagingActionBar(
              onPickImages: () => _pickImages(context),
              onPickPdfs: () => _pickPdfs(context),
              onSubmit: () => _submitForValidation(context),
              canSubmit: _canSubmit,
              isLoading: widget.isLoading || _isUploading,
            ),
        ],
      );
    }

    // Default (non-embedded) layout: self-contained with scroll + action bar.
    return Column(
      children: [
        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _allFiles.isEmpty
                ? _EmptyFiles(canModify: widget.canModify)
                : StagedFileGrid(
                    files: _allFiles,
                    maxFiles: widget.maxFiles,
                    canModify: widget.canModify,
                    onRemoveLocal: _removeLocalFile,
                    onDeleteRemote: _deleteRemoteFile,
                  ),
          ),
        ),

        // Action bar — always at the bottom, no GlobalKey needed
        if (widget.canModify)
          _EvidenceStagingActionBar(
            onPickImages: () => _pickImages(context),
            onPickPdfs: () => _pickPdfs(context),
            onSubmit: () => _submitForValidation(context),
            canSubmit: _canSubmit,
            isLoading: widget.isLoading || _isUploading,
          ),
      ],
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyFiles extends StatelessWidget {
  final bool canModify;

  const _EmptyFiles({required this.canModify});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFiles01,
            size: 48,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            canModify
                ? 'Aún no hay archivos. Usá los botones de abajo para agregar evidencias.'
                : 'No hay archivos de evidencia.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// I-2: Bottom action bar is now a private widget inside the manager file.
/// It takes simple callbacks instead of requiring access to the manager's state
/// via a GlobalKey. The parent screen never needs to reference the manager state.
class _EvidenceStagingActionBar extends StatelessWidget {
  final VoidCallback onPickImages;
  final VoidCallback onPickPdfs;
  final VoidCallback onSubmit;
  final bool canSubmit;
  final bool isLoading;

  const _EvidenceStagingActionBar({
    required this.onPickImages,
    required this.onPickPdfs,
    required this.onSubmit,
    required this.canSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Upload buttons row
          Row(
            children: [
              Expanded(
                child: SacButton.outline(
                  text: 'Imagen',
                  icon: HugeIcons.strokeRoundedCamera01,
                  isEnabled: !isLoading,
                  onPressed: !isLoading ? onPickImages : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SacButton.outline(
                  text: 'PDF',
                  icon: HugeIcons.strokeRoundedPdf01,
                  isEnabled: !isLoading,
                  onPressed: !isLoading ? onPickPdfs : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Submit button
          SacButton.primary(
            text: 'Enviar a validación',
            icon: HugeIcons.strokeRoundedSent,
            isEnabled: canSubmit && !isLoading,
            isLoading: isLoading,
            onPressed: canSubmit && !isLoading ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
