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
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/certificate_import_payloads.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_back_button.dart';

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

/// What the screen is waiting for while [CertificateImportUploadView] is busy.
enum CertificateImportUploadPhase { uploading, reading }

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
  final ValueNotifier<CertificateImportUploadPhase> _phase =
      ValueNotifier(CertificateImportUploadPhase.uploading);

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CertificateImportUploadView(
      phase: _phase,
      onSubmitProofs: (proof) async {
        _phase.value = CertificateImportUploadPhase.uploading;
        final result =
            await ref.read(uploadCertificateImportProofProvider).call(proof);
        await result.fold(
          (failure) async => throw failure,
          (batch) async {
            if (mounted) _phase.value = CertificateImportUploadPhase.reading;
            // A failed or empty reading still leaves the sealed file for manual entry.
            final ocr = await ref
                .read(processCertificateImportOcrProvider)
                .call(batch.id);
            await ocr.fold((_) async {}, (queued) async {
              if (queued.items.isNotEmpty) return;
              for (var attempt = 0; attempt < 6; attempt++) {
                await Future<void>.delayed(const Duration(seconds: 2));
                final detail = await ref
                    .read(getCertificateImportBatchProvider)
                    .call(batch.id);
                final ready = detail.fold(
                  (_) => true,
                  (loaded) => loaded.items.isNotEmpty,
                );
                if (ready) return;
              }
            });
            if (context.mounted) {
              context.push(RouteNames.certificateImportReviewPath(batch.id));
            }
          },
        );
      },
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
  });

  final CertificateImportSubmit? onSubmitProofs;
  final CertificateImportProofPicker? onPickCamera;
  final CertificateImportProofPicker? onPickGallery;
  final CertificateImportProofPicker? onPickFile;

  /// Current waiting phase while submitting; defaults to uploading.
  final ValueListenable<CertificateImportUploadPhase>? phase;

  @override
  State<CertificateImportUploadView> createState() =>
      _CertificateImportUploadViewState();
}

class _CertificateImportUploadViewState
    extends State<CertificateImportUploadView> {
  bool _loading = false;
  bool _picking = false;
  String? _error;
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
              ListView(
                padding: SacTopBar.paddingBelowBar(
                    context, const EdgeInsets.fromLTRB(18, 8, 18, 190)),
                children: [
                  _UploadHero(),
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  if (_hasFilesToAnalyze) ...[
                    const SizedBox(height: 12),
                    _SelectedProofCard(proof: _selectedProof!),
                  ],
                ],
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
                            _UploadProgressPanel(phase: widget.phase)
                          else
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
                            isEnabled: !_loading,
                            onPressed:
                                _picking || _loading ? null : _chooseSource,
                          ),
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
      setState(() => _error = 'certificate_import.upload.picker_error'.tr());
      return;
    }

    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await picker();
      if (file == null) return;
      if (!mounted) return;

      final validationError = _validateProof(file);
      if (validationError != null) {
        setState(() {
          _selectedProof = null;
          _error = validationError;
        });
        return;
      }

      setState(() {
        // Un documento por carga.
        _selectedProof = file;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  String _uploadErrorMessage(Object error) {
    final message = error is Failure ? error.message : error.toString();
    switch (message) {
      case 'CERTIFICATE_IMPORT_PDF_TOO_MANY_PAGES':
        return 'certificate_import.upload.pdf_too_many_pages'.tr();
      case 'CERTIFICATE_IMPORT_PDF_ENCRYPTED':
        return 'certificate_import.upload.pdf_encrypted'.tr();
      case 'CERTIFICATE_IMPORT_PDF_INVALID':
        return 'certificate_import.upload.pdf_invalid'.tr();
      default:
        return message;
    }
  }

  Future<void> _submit() async {
    final proof = _selectedProof;
    if (proof == null) return;
    if (widget.onSubmitProofs == null) {
      setState(
        () => _error = 'certificate_import.upload.no_submit'.tr(),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmitProofs!(proof);
    } catch (error) {
      if (mounted) setState(() => _error = _uploadErrorMessage(error));
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

/// Busy state shown in place of the primary button while a proof is sent.
///
/// Three-dot [SacLoadingSmall] (static under Reduced Motion) plus a clear
/// message, announced to assistive tech as a live region.
class _UploadProgressPanel extends StatelessWidget {
  const _UploadProgressPanel({this.phase});

  final ValueListenable<CertificateImportUploadPhase>? phase;

  @override
  Widget build(BuildContext context) {
    final listenable = phase;
    if (listenable == null) {
      return _body(context, CertificateImportUploadPhase.uploading);
    }
    return ValueListenableBuilder<CertificateImportUploadPhase>(
      valueListenable: listenable,
      builder: (context, value, _) => _body(context, value),
    );
  }

  Widget _body(BuildContext context, CertificateImportUploadPhase value) {
    final c = context.sac;
    final message = value == CertificateImportUploadPhase.reading
        ? 'certificate_import.upload.reading'.tr()
        : 'certificate_import.upload.uploading'.tr();
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SacLoadingSmall(),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
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
