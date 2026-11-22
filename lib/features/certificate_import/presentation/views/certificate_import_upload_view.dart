import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/certificate_import_payloads.dart';
import '../controllers/certificate_import_upload_controller.dart';
import '../error/certificate_import_error_mapper.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_back_button.dart';
import '../widgets/import_recent_batches.dart';
import '../widgets/import_proof_preview.dart';
import '../widgets/import_status_card.dart';
import '../widgets/import_upload_progress.dart';

typedef CertificateImportSubmit = Future<void> Function(
    CertificateImportLocalProof proof);
typedef CertificateImportProofPicker = Future<CertificateImportLocalProof?>
    Function();

/// Pages a PDF proof may have (matches the backend limit); a photo is one.
const int certificateImportMaxProofPages = 5;

/// Maximum proof size accepted client-side (matches the backend limit).
const int certificateImportMaxProofBytes = 10 * 1024 * 1024;

/// MIME types accepted for a proof: PDF plus JPEG, PNG and WebP images.
const Set<String> certificateImportAllowedMimeTypes = {
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/webp',
};

/// Where a proof comes from, offered in the "add proof" bottom sheet.
enum _ProofSource { camera, gallery, file }

class CertificateImportUploadRouteView extends ConsumerStatefulWidget {
  const CertificateImportUploadRouteView({super.key});

  @override
  ConsumerState<CertificateImportUploadRouteView> createState() =>
      _CertificateImportUploadRouteViewState();

  /// Picks an image from [source] and maps it to a local proof.
  ///
  /// [pickImage] is injectable so tests can verify the [ImageSource] used
  /// without touching the platform plugin.
  @visibleForTesting
  static Future<CertificateImportLocalProof?> pickImageProof(
    ImageSource source, {
    Future<XFile?> Function(ImageSource source)? pickImage,
  }) async {
    final image = await (pickImage ?? _defaultPickImage)(source);
    if (image == null) return null;

    final path = image.path;
    final size = await File(path).length();
    return CertificateImportLocalProof(
      localPath: path,
      fileName: image.name.isNotEmpty ? image.name : 'comprobante.jpg',
      mimeType: image.mimeType ?? lookupMimeType(path) ?? 'image/jpeg',
      fileSize: size,
    );
  }

  static Future<XFile?> _defaultPickImage(ImageSource source) {
    return ImagePicker().pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
  }

  static Future<CertificateImportLocalProof?> _pickCameraProof() =>
      pickImageProof(ImageSource.camera);

  static Future<CertificateImportLocalProof?> _pickGalleryProof() =>
      pickImageProof(ImageSource.gallery);

  static Future<CertificateImportLocalProof?> _pickFileProof() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return null;

    final path = file.path;
    if (path == null || path.trim().isEmpty) return null;

    final size = await file.length() ?? await File(path).length();
    return CertificateImportLocalProof(
      localPath: path,
      fileName: file.name,
      mimeType: lookupMimeType(path) ??
          _mimeTypeFromExtension(file.extension) ??
          'application/octet-stream',
      fileSize: size,
    );
  }

  static String? _mimeTypeFromExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
    }
    return null;
  }
}

class _CertificateImportUploadRouteViewState
    extends ConsumerState<CertificateImportUploadRouteView> {
  late final CertificateImportUploadController _controller =
      CertificateImportUploadController(
    ref.read(certificateImportRepositoryProvider),
    deleteBatch: ref.read(deleteCertificateImportBatchProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pull to refresh: reloads "Tus envíos" to see what the reviewer decided.
  Future<void> _refreshBatches() async {
    ref.invalidate(certificateImportBatchListProvider);
    try {
      await ref.read(
        certificateImportBatchListProvider(ImportRecentBatches.page).future,
      );
    } catch (_) {
      // The list hides itself on error; nothing to show here.
    }
  }

  Future<void> _submit(CertificateImportLocalProof proof) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await _controller.run(proof);
    if (!mounted) return;
    // The reading could not start: say so instead of landing on an empty
    // review with no explanation. The batch is still usable by hand.
    final issue = outcome.readingIssue;
    if (issue != null) {
      SacSnackBar.showMessenger(
        messenger,
        '${issue.title}. ${issue.body}',
        duration: const Duration(seconds: 6),
      );
    }
    // The new draft belongs in the recent list when the member comes back.
    ref.invalidate(certificateImportBatchListProvider);
    // The just-uploaded file lets the review thumbnail and viewer work offline.
    context.push(
      RouteNames.certificateImportReviewPath(outcome.batchId),
      extra: proof.localPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CertificateImportUploadView(
      phase: _controller.phase,
      progress: _controller.progress,
      slow: _controller.slow,
      onCancel: _controller.cancel,
      onSkipWait: _controller.skipWait,
      onSubmitProofs: _submit,
      onPickCamera: CertificateImportUploadRouteView._pickCameraProof,
      onPickGallery: CertificateImportUploadRouteView._pickGalleryProof,
      onPickFile: CertificateImportUploadRouteView._pickFileProof,
      recentBatches: const ImportRecentBatches(),
      onRefresh: _refreshBatches,
    );
  }
}

class CertificateImportUploadView extends StatefulWidget {
  const CertificateImportUploadView({
    super.key,
    this.onSubmitProofs,
    this.onPickCamera,
    this.onPickGallery,
    this.onPickFile,
    this.phase,
    this.progress,
    this.slow,
    this.onCancel,
    this.onSkipWait,
    this.recentBatches,
    this.onRefresh,
  });

  final CertificateImportSubmit? onSubmitProofs;
  final CertificateImportProofPicker? onPickCamera;
  final CertificateImportProofPicker? onPickGallery;
  final CertificateImportProofPicker? onPickFile;

  /// Current waiting phase while submitting; defaults to uploading.
  final ValueListenable<CertificateImportUploadPhase>? phase;

  /// Real upload progress from 0 to 1; hides the bar when absent.
  final ValueListenable<double>? progress;

  /// True once reading is taking long; offers [onSkipWait].
  final ValueListenable<bool>? slow;

  /// Cancels the upload in flight ("Cancelar", only while uploading).
  final VoidCallback? onCancel;

  /// Leaves the wait and opens the review ("Seguir sin esperar").
  final VoidCallback? onSkipWait;

  /// The member's earlier batches, below the upload hint. Comes from the
  /// route so this view stays free of providers.
  final Widget? recentBatches;

  /// Reloads [recentBatches]; without it there is no pull to refresh.
  final Future<void> Function()? onRefresh;

  @override
  State<CertificateImportUploadView> createState() =>
      _CertificateImportUploadViewState();
}

class _CertificateImportUploadViewState
    extends State<CertificateImportUploadView> {
  bool _loading = false;
  bool _picking = false;

  /// Local validation problem (C0): the file itself cannot be used.
  String? _localError;

  /// Upload failure (C1 to C3 and unexpected), already classified.
  CertificateImportErrorInfo? _uploadError;
  CertificateImportLocalProof? _selectedProof;

  bool get _hasFilesToAnalyze => _selectedProof != null;

  /// Pull to refresh under the frosted bar, never while uploading.
  Widget _maybeRefresh(BuildContext context, Widget child) {
    final reload = widget.onRefresh;
    if (reload == null || _loading) return child;
    return RefreshIndicator(
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: reload,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasIssue = _localError != null || _uploadError != null;
    // An upload failure takes the place of the selected-file card.
    final showPreview = _hasFilesToAnalyze && _uploadError == null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'certificate_import.upload.title'.tr(),
          leading: const CertificateImportBackButton(
            fallbackLocation: RouteNames.homeProfile,
          ),
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Stack(
            children: [
              AbsorbPointer(
                absorbing: _loading,
                child: _maybeRefresh(
                  context,
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: SacTopBar.paddingBelowBar(
                        context, const EdgeInsets.fromLTRB(0, 8, 0, 130)),
                    children: [
                      if (_loading)
                        ImportUploadProgress(
                          phase: widget.phase,
                          progress: widget.progress,
                          slow: widget.slow,
                        )
                      else ...[
                        _Lead(showHint: !_hasFilesToAnalyze),
                        if (hasIssue) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SacStateSwap(child: _buildIssueCard()),
                          ),
                        ],
                        if (showPreview)
                          ImportProofPreview(
                            proof: _selectedProof!,
                            onChange: _picking ? null : _chooseSource,
                          ),
                        if (widget.recentBatches != null) widget.recentBatches!,
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildDock(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ONE fixed action: "Agregar comprobante" until a proof is chosen, then
  /// "Leer comprobante". While the proof is sent and read the dock only
  /// offers the way out ("Cancelar" while uploading, "Seguir sin esperar"
  /// when the reading is slow) and takes no space when there is none.
  Widget _buildDock(BuildContext context) {
    if (_loading) {
      return _WaitActions(
        phase: widget.phase,
        slow: widget.slow,
        onCancel: widget.onCancel,
        onSkipWait: widget.onSkipWait,
        dock: _dock,
      );
    }
    return _dock(
      _hasFilesToAnalyze
          ? SacButton.primary(
              text: 'certificate_import.upload.submit'.tr(),
              icon: HugeIcons.strokeRoundedFileUpload,
              onPressed: _submit,
            )
          : SacButton.primary(
              text: 'certificate_import.upload.choose'.tr(),
              icon: HugeIcons.strokeRoundedImageUpload,
              isLoading: _picking,
              onPressed: _picking ? null : _chooseSource,
            ),
    );
  }

  /// The fixed bar at the bottom that holds the one action.
  Widget _dock(Widget action) {
    final c = context.sac;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: action,
        ),
      ),
    );
  }

  Widget _buildIssueCard() {
    final error = _uploadError;
    if (error != null) {
      return ImportStatusCard.fromError(
        error,
        onRetry: _loading ? null : _submit,
        onChooseOther: _picking || _loading ? null : _chooseSource,
      );
    }
    return ImportStatusCard(
      key: const ValueKey('import-status-local'),
      icon: HugeIcons.strokeRoundedAlert02,
      title: 'certificate_import.errors.local_file.title'.tr(),
      body: _localError!,
      primaryLabel: 'certificate_import.errors.choose_other_short'.tr(),
      onPrimary: _picking || _loading ? null : _chooseSource,
    );
  }

  Future<void> _chooseSource() async {
    final source = await _showProofSourceSheet(context);
    if (source == null || !mounted) return;
    switch (source) {
      case _ProofSource.camera:
        await _pickProof(widget.onPickCamera);
      case _ProofSource.gallery:
        await _pickProof(widget.onPickGallery);
      case _ProofSource.file:
        await _pickProof(widget.onPickFile);
    }
  }

  /// Same rules for camera, gallery and files: PDF/JPEG/PNG/WebP, max 10 MiB.
  String? _validateProof(CertificateImportLocalProof proof) {
    if (!certificateImportAllowedMimeTypes
        .contains(proof.mimeType.toLowerCase())) {
      return 'certificate_import.upload.unsupported_type'.tr();
    }
    if (proof.fileSize > certificateImportMaxProofBytes) {
      return 'certificate_import.upload.too_large'.tr();
    }
    return null;
  }

  Future<void> _pickProof(CertificateImportProofPicker? picker) async {
    if (picker == null) {
      setState(
          () => _localError = 'certificate_import.upload.picker_error'.tr());
      return;
    }

    setState(() {
      _picking = true;
      _localError = null;
      _uploadError = null;
    });
    try {
      final file = await picker();
      if (file == null) return;
      if (!mounted) return;

      final validationError = _validateProof(file);
      if (validationError != null) {
        setState(() {
          _selectedProof = null;
          _localError = validationError;
        });
        return;
      }

      setState(() {
        // Un documento por carga.
        _selectedProof = file;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _localError = 'certificate_import.upload.picker_error'.tr());
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    final proof = _selectedProof;
    if (proof == null) return;
    if (widget.onSubmitProofs == null) {
      setState(
        () => _localError = 'certificate_import.upload.no_submit'.tr(),
      );
      return;
    }

    setState(() {
      _loading = true;
      _localError = null;
      _uploadError = null;
    });
    try {
      await widget.onSubmitProofs!(proof);
    } on CertificateImportUploadCancelled {
      // The user cancelled: back to the selected file, no error.
    } catch (error) {
      if (mounted) {
        setState(() => _uploadError = CertificateImportErrorMapper.map(
              error,
              context: CertificateImportErrorContext.upload,
            ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

Future<_ProofSource?> _showProofSourceSheet(BuildContext context) {
  return showSacSheet<_ProofSource>(
    context: context,
    // Lets the sheet grow past the default 9/16 cap on short screens or with
    // large text scale instead of overflowing.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SacSheetHeader(
                title: 'certificate_import.upload.source_title'.tr()),
            _ProofSourceTile(
              icon: HugeIcons.strokeRoundedCamera01,
              title: 'certificate_import.upload.camera'.tr(),
              subtitle: 'certificate_import.upload.camera_sub'.tr(),
              onTap: () => Navigator.pop(ctx, _ProofSource.camera),
            ),
            _ProofSourceTile(
              icon: HugeIcons.strokeRoundedImage01,
              title: 'certificate_import.upload.gallery'.tr(),
              subtitle: 'certificate_import.upload.gallery_sub'.tr(),
              onTap: () => Navigator.pop(ctx, _ProofSource.gallery),
            ),
            _ProofSourceTile(
              icon: HugeIcons.strokeRoundedFolder01,
              title: 'certificate_import.upload.file'.tr(),
              subtitle: 'certificate_import.upload.file_sub'.tr(),
              onTap: () => Navigator.pop(ctx, _ProofSource.file),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

class _ProofSourceTile extends StatelessWidget {
  const _ProofSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final HugeIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    return SacPressable(
      listenOnly: true,
      child: ListTile(
        enableFeedback: false,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.light,
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 22, color: accent.color),
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

/// The two-line lead and, before a proof is chosen, what is accepted.
class _Lead extends StatelessWidget {
  const _Lead({required this.showHint});

  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'certificate_import.upload.lead'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.titleMedium,
              height: 1.45,
              color: c.text,
            ),
          ),
          if (showHint) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    size: 16,
                    color: c.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'certificate_import.upload.hint'.tr(namedArgs: {
                      'pages': '$certificateImportMaxProofPages',
                      'mb':
                          '${certificateImportMaxProofBytes ~/ (1024 * 1024)}',
                    }),
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      height: 1.4,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The way out while the proof is sent and read: "Cancelar" while uploading,
/// "Seguir sin esperar" when the reading is slow. Nothing otherwise.
class _WaitActions extends StatelessWidget {
  const _WaitActions({
    this.phase,
    this.slow,
    this.onCancel,
    this.onSkipWait,
    required this.dock,
  });

  final ValueListenable<CertificateImportUploadPhase>? phase;
  final ValueListenable<bool>? slow;
  final VoidCallback? onCancel;
  final VoidCallback? onSkipWait;

  /// Wraps the action in the fixed bottom bar.
  final Widget Function(Widget action) dock;

  @override
  Widget build(BuildContext context) {
    final listenables = [
      if (phase != null) phase!,
      if (slow != null) slow!,
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final reading = phase?.value == CertificateImportUploadPhase.reading;
        if (!reading && onCancel != null) {
          return dock(SacButton.outline(
            text: 'certificate_import.upload.cancel'.tr(),
            onPressed: onCancel,
          ));
        }
        if (reading && (slow?.value ?? false) && onSkipWait != null) {
          return dock(SacButton.outline(
            text: 'certificate_import.upload.skip_wait'.tr(),
            onPressed: onSkipWait,
          ));
        }
        // Nothing to offer: no empty bar.
        return const SizedBox.shrink();
      },
    );
  }
}
