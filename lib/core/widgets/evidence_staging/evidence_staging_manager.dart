import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../animations/sac_rolling_number.dart';
import '../../errors/exceptions.dart';
import '../../theme/sac_colors.dart';
import '../../utils/app_logger.dart';
import '../sac_button.dart';
import '../sac_dialog.dart';
import '../sac_snack_bar.dart';
import 'evidence_footer_bar.dart';
import 'evidence_footer_presence.dart';
import 'evidence_send_label.dart';
import 'evidence_source_sheet.dart';
import 'staged_file.dart';
import 'staged_file_grid.dart';
import 'upload_progress_sheet.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
  /// [SingleChildScrollView] wrapper.
  ///
  /// Use this when embedding the staging manager inside a parent scroll view.
  /// The parent is responsible for providing scrolling.
  ///
  /// Defaults to false for backward compatibility.
  final bool embeddedMode;

  /// Whether this manager should render its own action bar.
  ///
  /// Set this to false when the parent needs to pin the action bar in a
  /// [Scaffold.bottomNavigationBar] while keeping the staging content inside
  /// the scrollable body.
  final bool showActionBar;

  /// Notifies the parent when action-bar derived state changes.
  ///
  /// Useful when [showActionBar] is false and the parent renders
  /// [EvidenceStagingActionBar] outside this widget.
  final VoidCallback? onActionStateChanged;

  /// Already translated name of the files section ("Files"). In the add-tile
  /// layout the manager draws it as an eyebrow with the live "N of M" count
  /// above the grid. Null draws no eyebrow.
  final String? sectionTitle;

  /// The footer action re-sends a returned item ("Resend") instead of
  /// "Send N files".
  final bool isResend;

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
    this.showActionBar = true,
    this.onActionStateChanged,
    this.sectionTitle,
    this.isResend = false,
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
  bool? _lastNotifiedCanSubmit;
  bool? _lastNotifiedIsLoading;
  int? _lastNotifiedFileCount;

  @override
  void initState() {
    super.initState();
    _allFiles = List.from(widget.existingFiles);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyActionStateChanged();
    });
  }

  @override
  void didUpdateWidget(covariant EvidenceStagingManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When parent rebuilds with new existing files (e.g. after provider
    // invalidation), merge them with any remaining local files.
    //
    // Use the same predicate as _queueFiles (status != uploaded) so that
    // files in any in-flight state (local, uploading, completed, error) are
    // preserved during a mid-upload parent rebuild. The previous filter
    // (f.isLocal) only kept status == local, which caused files that had
    // already transitioned to uploading/completed to be dropped from
    // _allFiles the moment the notifier emitted isLoading:true and the
    // parent rebuilt — making _queueFiles return [] and the sheet show the
    // premature "all done" state (Bug B).
    if (!listEquals(oldWidget.existingFiles, widget.existingFiles)) {
      final queueFiles = _allFiles
          .where((f) => f.status != StagedFileStatus.uploaded)
          .toList();
      _allFiles = [...widget.existingFiles, ...queueFiles];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyActionStateChanged();
      });
    }
  }

  // ── Computed ────────────────────────────────────────────────────────────────

  List<StagedFile> get _localFiles =>
      _allFiles.where((f) => f.isLocal).toList();

  /// All files that are part of the current upload queue (local, uploading,
  /// completed, or errored). Excludes already-remote (`uploaded`) files.
  /// Used to feed the upload progress sheet so it always sees the full queue
  /// regardless of the individual file status transitions.
  List<StagedFile> get _queueFiles =>
      _allFiles.where((f) => f.status != StagedFileStatus.uploaded).toList();

  bool get _hasLocalFiles => _localFiles.isNotEmpty;

  bool get _hasAnyFiles => _allFiles.isNotEmpty;

  bool get _isOverLimit => _allFiles.length > widget.maxFiles;

  /// Whether the "Enviar" button should be enabled.
  bool get _canSubmit =>
      widget.canModify && !_isUploading && _hasAnyFiles && !_isOverLimit;

  /// Public view of submit availability for externally pinned action bars.
  bool get canSubmitForActionBar => _canSubmit;

  /// Public view of busy state for externally pinned action bars.
  bool get isLoadingForActionBar => widget.isLoading || _isUploading;

  /// Files the footer action will send (already uploaded plus staged).
  int get fileCountForActionBar => _allFiles.length;

  /// Opens the source sheet (camera, gallery or PDF) and stages what is
  /// picked. This is what the add tile does.
  Future<void> addFiles() => _addFiles(context);

  /// Triggers upload + submit from an externally rendered action bar.
  Future<void> submitForValidation() => _submitForValidation(context);

  /// Notifies the parent whenever the local file count changes.
  /// Used for PopScope without GlobalKey (I-2 fix).
  void _notifyLocalFilesChanged() {
    widget.onLocalFilesChanged?.call(_hasLocalFiles);
    _notifyActionStateChanged();
  }

  void _notifyActionStateChanged() {
    final canSubmit = _canSubmit;
    final isLoading = isLoadingForActionBar;
    final fileCount = fileCountForActionBar;
    if (_lastNotifiedCanSubmit == canSubmit &&
        _lastNotifiedIsLoading == isLoading &&
        _lastNotifiedFileCount == fileCount) {
      return;
    }
    _lastNotifiedCanSubmit = canSubmit;
    _lastNotifiedIsLoading = isLoading;
    _lastNotifiedFileCount = fileCount;
    widget.onActionStateChanged?.call();
  }

  List<StagedFile> _renumberLocalFiles(List<StagedFile> files) {
    var displayIndex = 0;

    return files.map((file) {
      if (file.status == StagedFileStatus.uploaded) {
        displayIndex++;
        return file;
      }

      if (file.status == StagedFileStatus.local) {
        displayIndex++;
        return file.copyWith(
          name: widget.fileNameBuilder(file.name, displayIndex),
        );
      }

      return file;
    }).toList();
  }

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> _addFiles(BuildContext context) async {
    final source = await showEvidenceSourceSheet(context);
    if (source == null || !mounted) return;
    switch (source) {
      case EvidenceSource.camera:
        // ignore: use_build_context_synchronously
        await _pickImagesFrom(context, ImageSource.camera);
      case EvidenceSource.gallery:
        // ignore: use_build_context_synchronously
        await _pickImagesFrom(context, ImageSource.gallery);
      case EvidenceSource.pdf:
        // ignore: use_build_context_synchronously
        await _pickPdfs(context);
    }
  }

  Future<void> _pickImagesFrom(
    BuildContext context,
    ImageSource source,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

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
          (skippedCount == 1
                  ? 'core.evidence_staging.image_size_exceeded_one'
                  : 'core.evidence_staging.image_size_exceeded_other')
              .tr(namedArgs: {'count': '$skippedCount'}),
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
        _allFiles = _renumberLocalFiles([..._allFiles, ...newFiles]);
      });
      _notifyLocalFilesChanged();
    } catch (e) {
      AppLogger.e('Error al seleccionar imagen', error: e);
      _showErrorSnackbarViaMessenger(
          messenger, tr('core.evidence_staging.error_select_image'));
    }
  }

  Future<void> _pickPdfs(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (picked.isEmpty || !mounted) return;

      // Validate file sizes before staging. A size that cannot be read counts
      // as 0; the server still enforces the limit.
      final validPdfs = picked.where((pf) => pf.path != null).toList();
      final sizes = [for (final pf in validPdfs) await pf.length() ?? 0];
      if (!mounted) return;
      final oversized = [
        for (var i = 0; i < validPdfs.length; i++)
          if (sizes[i] > _maxFileSizeBytes) validPdfs[i],
      ];
      final acceptedPdfs = [
        for (var i = 0; i < validPdfs.length; i++)
          if (sizes[i] <= _maxFileSizeBytes) validPdfs[i],
      ];

      if (oversized.isNotEmpty && mounted) {
        final count = oversized.length;
        _showErrorSnackbar(
          context, // ignore: use_build_context_synchronously
          (count == 1
                  ? 'core.evidence_staging.pdf_size_exceeded_one'
                  : 'core.evidence_staging.pdf_size_exceeded_other')
              .tr(namedArgs: {'count': '$count'}),
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
        _allFiles = _renumberLocalFiles([..._allFiles, ...newFiles]);
      });
      _notifyLocalFilesChanged();
    } catch (e) {
      AppLogger.e('Error al seleccionar PDF', error: e);
      _showErrorSnackbarViaMessenger(
          messenger, tr('core.evidence_staging.error_select_pdf'));
    }
  }

  // ── Local file removal ──────────────────────────────────────────────────────

  // I-3: Never mutate _allFiles in place — always create a new list.
  void _removeLocalFile(StagedFile file) {
    setState(() {
      _allFiles = _renumberLocalFiles(
        _allFiles.where((f) => f.id != file.id).toList(),
      );
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
          _allFiles = _renumberLocalFiles(
            _allFiles.where((f) => f.id != file.id).toList(),
          );
        });
        _notifyActionStateChanged();
      }
    } catch (e) {
      AppLogger.e('Error al eliminar archivo', error: e);
      if (mounted) {
        _showErrorSnackbar(
            context, tr('core.evidence_staging.error_delete_file'));
      }
    }
  }

  // ── Upload + Submit flow ──────────────────────────────────────────────────

  Future<void> _submitForValidation(BuildContext context) async {
    HapticFeedback.lightImpact();
    // If no local files, skip upload and go straight to submit
    if (!_hasLocalFiles) {
      await _confirmAndSubmit(context);
      return;
    }

    // If over limit, block
    if (_isOverLimit) {
      _showErrorSnackbar(
        context,
        tr('core.evidence_staging.error_over_limit'),
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
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _allFiles = _renumberLocalFiles(_allFiles);
      _isUploading = true;
    });
    _notifyActionStateChanged();

    // Prepare the upload stream controller
    final streamController = StreamController<List<StagedFile>>.broadcast();

    final localFiles = _localFiles;

    // Show the progress sheet
    // Pass _queueFiles (not _localFiles) as initialFiles so the sheet sees all
    // files in the queue from the start. _localFiles filters by status == local
    // which causes files to disappear from the list as soon as they transition
    // to uploading/completed/error — the sheet would see an empty list and
    // prematurely show the "all done" state before uploads finish (Bug A).
    final sheetResultFuture = showUploadProgressSheet(
      context: context,
      initialFiles: _queueFiles,
      uploadStream: streamController.stream,
    );

    // Execute uploads sequentially
    for (int i = 0; i < localFiles.length; i++) {
      final file = localFiles[i];
      final fileName = file.name;

      // Transition to uploading
      _updateFileStatus(
        file.id,
        StagedFileStatus.uploading,
        uploadProgress: 0.0,
      );
      // Emit _queueFiles (includes uploading/completed/error) so the sheet
      // always sees every file in the queue regardless of status transition.
      streamController.add(_queueFiles);

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
            streamController.add(_queueFiles);
          },
        );

        // Success
        _updateFileStatus(file.id, StagedFileStatus.completed);
        streamController.add(_queueFiles);
      } catch (e) {
        AppLogger.e('Error uploading file: ${file.name}', error: e);
        _updateFileStatus(
          file.id,
          StagedFileStatus.error,
          errorMessage: stagedUploadErrorMessage(e),
        );
        streamController.add(_queueFiles);
      }
    }

    // Wait for user action on the sheet
    final sheetResult = await sheetResultFuture;
    await streamController.close();

    if (!mounted) return;

    setState(() => _isUploading = false);
    _notifyActionStateChanged();

    // I-3: Never mutate _allFiles in place — always create a new list.
    switch (sheetResult) {
      case UploadSheetResult.continueSubmit:
      case UploadSheetResult.continuePartial:
        // Guard: at least one file must have been uploaded (now or previously)
        final hasCompletedFiles =
            _allFiles.any((f) => f.status == StagedFileStatus.completed);
        final hasRemoteFiles =
            _allFiles.any((f) => f.status == StagedFileStatus.uploaded);

        if (!hasCompletedFiles && !hasRemoteFiles) {
          _showErrorSnackbarViaMessenger(
            messenger,
            tr('core.evidence_staging.error_upload_none'),
          );
          break;
        }

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
    final fileCountLabel = newFiles > 0
        ? 'core.evidence_staging.submit_dialog_file_count_with_new'.plural(
            newFiles,
            name: 'count',
            namedArgs: {'total': '$totalFiles'},
          )
        : tr(
            'core.evidence_staging.submit_dialog_file_count',
            namedArgs: {'total': '$totalFiles'},
          );

    final result = await SacDialog.show(
      context,
      title: tr('core.evidence_staging.submit_dialog_title'),
      content: tr('core.evidence_staging.submit_dialog_body'),
      highlight: fileCountLabel,
      icon: HugeIcons.strokeRoundedMailSend01,
      cancelLabel: tr('core.evidence_staging.cancel'),
      confirmLabel: tr('core.evidence_staging.submit'),
      // Sending to validation is a positive action: do not use the coral
      // confirm (reads as destructive).
      confirmIsSuccess: true,
    );
    return result ?? false;
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!mounted) return;
    SacSnackBar.show(
      context,
      message,
      isError: true,
      leading: const HugeIcon(
        icon: HugeIcons.strokeRoundedAlert02,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  void _showErrorSnackbarViaMessenger(
      ScaffoldMessengerState messenger, String message) {
    if (!mounted) return;
    SacSnackBar.showMessenger(
      messenger,
      message,
      isError: true,
      leading: const HugeIcon(
        icon: HugeIcons.strokeRoundedAlert02,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  // I-2: By default the action bar is built directly inside this widget's
  // build method. Screens that need fixed placement can set showActionBar:false
  // and render EvidenceStagingActionBar in Scaffold.bottomNavigationBar.
  // I-5: No mid-batch invalidation issue since C-2 (skipInvalidation) ensures
  // providers are not invalidated during batch uploads. A single invalidation
  // happens after the full batch via the onSubmit callback.

  /// The files grid, or the empty message when there is nothing to show.
  Widget _buildGrid() {
    final showsAdd = widget.canModify;
    if (_allFiles.isEmpty && !showsAdd) {
      return _EmptyFiles(canModify: widget.canModify);
    }
    return StagedFileGrid(
      files: _allFiles,
      maxFiles: widget.maxFiles,
      canModify: widget.canModify,
      onRemoveLocal: _removeLocalFile,
      onDeleteRemote: _deleteRemoteFile,
      onAdd: showsAdd ? () => _addFiles(context) : null,
      showCounter: false,
    );
  }

  /// The "2 of 10" count; the first number rolls when it changes. Read-only
  /// screens show only the total.
  Widget _filesCount(TextStyle style) {
    const marker = '\u0001';
    var prefix = '';
    var suffix = '';
    if (widget.canModify) {
      final text = 'core.evidence_staging.files_of'.tr(namedArgs: {
        'count': marker,
        'max': '${widget.maxFiles}',
      });
      final at = text.indexOf(marker);
      if (at >= 0) {
        prefix = text.substring(0, at);
        suffix = text.substring(at + marker.length);
      }
    }
    return SacRollingNumber(
      textKey: const ValueKey('evidence-files-count'),
      value: _allFiles.length,
      prefix: prefix,
      suffix: suffix,
      style: style,
    );
  }

  /// "FILES   2 of 10" above the grid. Read-only screens show only the total.
  Widget _buildEyebrow() {
    final c = context.sac;
    final title = widget.sectionTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: c.textTertiary,
              ),
            ),
          ),
          _filesCount(
            TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w600,
              color: _isOverLimit ? c.error : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final hasEyebrow = widget.sectionTitle != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasEyebrow) _buildEyebrow(),
          _buildGrid(),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return EvidenceStagingActionBar(
      isResend: widget.isResend,
      fileCount: _allFiles.length,
      onSubmit: () => _submitForValidation(context),
      canSubmit: _canSubmit,
      isLoading: widget.isLoading || _isUploading,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Embedded mode: no Expanded, no SingleChildScrollView.
    // The parent provides scrolling via its own SingleChildScrollView.
    if (widget.embeddedMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildContent(),
          EvidenceFooterPresence(
            visible: widget.showActionBar && widget.canModify,
            child: _buildActionBar(),
          ),
        ],
      );
    }

    // Default (non-embedded) layout: self-contained with scroll + action bar.
    return Column(
      children: [
        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(child: _buildContent()),
        ),

        // Action bar — always at the bottom, no GlobalKey needed
        EvidenceFooterPresence(
          visible: widget.showActionBar && widget.canModify,
          child: _buildActionBar(),
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
                ? tr('core.evidence_staging.empty_can_modify')
                : tr('core.evidence_staging.empty_read_only'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable bottom action bar for evidence staging flows.
///
/// The manager renders this internally by default. Screens that need fixed
/// placement can render it in [Scaffold.bottomNavigationBar] and delegate the
/// callbacks back to [EvidenceStagingManagerState].
///
/// It holds one primary action, "Send N files" (or "Resend"), disabled while
/// nothing can be sent.
class EvidenceStagingActionBar extends StatelessWidget {
  final VoidCallback onSubmit;
  final bool canSubmit;
  final bool isLoading;

  /// Files that the action sends; fills "Send N files".
  final int fileCount;

  /// Shows "Resend" instead of "Send N files".
  final bool isResend;

  const EvidenceStagingActionBar({
    super.key,
    required this.onSubmit,
    required this.canSubmit,
    required this.isLoading,
    this.fileCount = 0,
    this.isResend = false,
  });

  String _submitText() {
    if (isResend) return tr('core.evidence_staging.btn_resend');
    if (fileCount <= 0) return tr('core.evidence_staging.btn_send_none');
    if (fileCount == 1) return tr('core.evidence_staging.btn_send_one');
    return tr(
      'core.evidence_staging.btn_send_many',
      namedArgs: {'count': '$fileCount'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return EvidenceFooterBar(
      child: SacButton.primary(
        key: const ValueKey('evidence-submit'),
        text: _submitText(),
        label: isResend ? null : EvidenceSendLabel(fileCount: fileCount),
        icon: HugeIcons.strokeRoundedSent,
        isEnabled: canSubmit && !isLoading,
        isLoading: isLoading,
        onPressed: canSubmit && !isLoading ? onSubmit : null,
      ),
    );
  }
}

/// Texto legible para el error de un archivo: el mensaje de una
/// [AppException] tal cual, y nunca el prefijo técnico `Exception: `.
@visibleForTesting
String stagedUploadErrorMessage(Object error) {
  if (error is AppException) return error.message;
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}
