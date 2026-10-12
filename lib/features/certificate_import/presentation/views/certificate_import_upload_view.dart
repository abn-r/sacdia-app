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
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/certificate_import_payloads.dart';
import '../controllers/certificate_import_upload_controller.dart';
import '../error/certificate_import_error_mapper.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_back_button.dart';
import '../widgets/import_status_card.dart';
import '../widgets/import_steps.dart';

typedef CertificateImportSubmit = Future<void> Function(
    CertificateImportLocalProof proof);
typedef CertificateImportProofPicker = Future<CertificateImportLocalProof?>
    Function();

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    if (path == null || path.trim().isEmpty) return null;

    final size = file.size > 0 ? file.size : await File(path).length();
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
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
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
                child: ListView(
                  padding: SacTopBar.paddingBelowBar(
                      context, const EdgeInsets.fromLTRB(18, 8, 18, 190)),
                  children: [
                    _UploadHero(),
                    // Right under the hero so it stays above the dock.
                    if (_localError != null || _uploadError != null) ...[
                      const SizedBox(height: 12),
                      SacStateSwap(child: _buildIssueCard()),
                    ],
                    const SizedBox(height: 14),
                    SacCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                              color: c.success),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'certificate_import.upload.hint'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: c.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // An upload failure takes the place of the selected-file card.
                    if (_hasFilesToAnalyze && _uploadError == null) ...[
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        opacity: _loading ? 0.6 : 1,
                        duration: SacMotion.reduceMotionOf(context)
                            ? SacMotion.reducedFade
                            : SacMotion.standard,
                        curve: SacMotion.easeOut,
                        child: _SelectedProofCard(proof: _selectedProof!),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.background,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_loading)
                            _UploadProgressPanel(
                              phase: widget.phase,
                              progress: widget.progress,
                              slow: widget.slow,
                              onCancel: widget.onCancel,
                              onSkipWait: widget.onSkipWait,
                            )
                          else ...[
                            SacButton.primary(
                              text: 'certificate_import.upload.submit'.tr(),
                              icon: HugeIcons.strokeRoundedFileUpload,
                              isEnabled: _hasFilesToAnalyze,
                              onPressed: !_hasFilesToAnalyze ? null : _submit,
                            ),
                            const SizedBox(height: 8),
                            SacButton.outline(
                              text: 'certificate_import.upload.choose'.tr(),
                              icon: HugeIcons.strokeRoundedImageUpload,
                              isLoading: _picking,
                              onPressed: _picking ? null : _chooseSource,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            borderRadius: BorderRadius.circular(10),
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

/// Busy state shown in place of the buttons while a proof is sent and read.
///
/// Steps, a three-dot [SacLoadingSmall] (static under Reduced Motion) with a
/// message announced as a live region, the real upload bar while uploading,
/// and the way out: "Cancelar" while uploading, "Seguir sin esperar" when the
/// reading is slow.
class _UploadProgressPanel extends StatelessWidget {
  const _UploadProgressPanel({
    this.phase,
    this.progress,
    this.slow,
    this.onCancel,
    this.onSkipWait,
  });

  final ValueListenable<CertificateImportUploadPhase>? phase;
  final ValueListenable<double>? progress;
  final ValueListenable<bool>? slow;
  final VoidCallback? onCancel;
  final VoidCallback? onSkipWait;

  @override
  Widget build(BuildContext context) {
    final listenables = [
      if (phase != null) phase!,
      if (progress != null) progress!,
      if (slow != null) slow!,
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final c = context.sac;
    final reading = phase?.value == CertificateImportUploadPhase.reading;
    final percent = ((progress?.value ?? 0) * 100).round().clamp(0, 100);
    // Screen readers hear 0, 25, 50, 75 and 100 % so they are not flooded.
    final announced = percent ~/ 25 * 25;
    String uploadingText(int value) => value > 0
        ? 'certificate_import.upload.uploading_pct'
            .tr(namedArgs: {'percent': '$value'})
        : 'certificate_import.upload.uploading'.tr();
    final message = reading
        ? (slow?.value ?? false
            ? 'certificate_import.upload.reading_slow'.tr()
            : 'certificate_import.upload.reading'.tr())
        : uploadingText(percent);
    final reduce = SacMotion.reduceMotionOf(context);
    final accent = SacAccent.of(context).color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ImportSteps(current: reading ? 1 : 0),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          container: true,
          label: reading ? message : uploadingText(announced),
          child: ExcludeSemantics(
            child: Container(
              key: const ValueKey('certificate-import-upload-progress'),
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: c.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SacLoadingSmall(),
                      const SizedBox(width: 12),
                      Flexible(
                        // Only the text fades; the loader never restarts.
                        child: AnimatedSwitcher(
                          duration: reduce
                              ? SacMotion.reducedFade
                              : SacMotion.switcher,
                          switchInCurve: SacMotion.easeOut,
                          switchOutCurve: SacMotion.easeOut,
                          child: Text(
                            message,
                            key: ValueKey(reading ? message : 'uploading'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Vision reports no progress, so no bar while reading.
                  if (!reading && progress != null) ...[
                    const SizedBox(height: 8),
                    SacTweenedBar(
                      value: progress!.value,
                      color: accent,
                      backgroundColor: c.border,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!reading && onCancel != null)
          SacButton.ghost(
            text: 'certificate_import.upload.cancel'.tr(),
            onPressed: onCancel,
          ),
        if (reading && (slow?.value ?? false) && onSkipWait != null)
          SacButton.ghost(
            text: 'certificate_import.upload.skip_wait'.tr(),
            onPressed: onSkipWait,
          ),
      ],
    );
  }
}

class _UploadHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacCard(
      backgroundColor: c.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.12,
                    child: const _ReceiptThumb(label: 'CMP-01'),
                  ),
                  Positioned(
                    left: 100,
                    child: Transform.rotate(
                      angle: 0.08,
                      child:
                          const _ReceiptThumb(label: 'CMP-02', compact: true),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 42,
                    child: HugeIcon(
                        icon: HugeIcons.strokeRoundedMagicWand01,
                        color: c.warning),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'certificate_import.upload.hero_title'.tr(),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'certificate_import.upload.hero_body'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _SelectedProofCard extends StatelessWidget {
  const _SelectedProofCard({required this.proof});

  final CertificateImportLocalProof proof;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFile01,
            color: c.success,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'certificate_import.upload.selected_one'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  proof.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptThumb extends StatelessWidget {
  const _ReceiptThumb({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: compact ? 88 : 110,
      height: compact ? 118 : 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 14),
          for (var i = 0; i < (compact ? 3 : 5); i++) ...[
            Container(
              height: compact ? 3 : 4,
              width: i.isEven ? 64 : 44,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
          ],
        ],
      ),
    );
  }
}
