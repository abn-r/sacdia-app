import 'dart:io';

import 'package:dartz/dartz.dart' show Either;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../errors/failures.dart';
import '../theme/app_colors.dart';
import '../theme/sac_accent.dart';
import '../theme/sac_colors.dart';
import '../utils/icon_helper.dart';
import '../widgets/sac_button.dart';
import '../widgets/sac_card.dart';
import '../widgets/sac_pressable.dart';
import '../widgets/sac_sheet.dart';
import 'consent_error_messages.dart';
import 'consent_evidence.dart';

/// Sube el archivo y devuelve el recibo o el fallo (con su `errorCode`).
typedef ConsentUploadCallback = Future<Either<Failure, ConsentEvidenceReceipt>>
    Function(ConsentEvidenceLocalFile file);

/// Hoja para elegir de dónde sale la ficha: cámara, galería o PDF.
Future<ConsentSource?> showConsentSourceSheet(BuildContext context) {
  return showSacSheet<ConsentSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SacSheetHeader(title: 'core.consent.source_title'.tr()),
          _SourceTile(
            icon: HugeIcons.strokeRoundedCamera01,
            title: 'core.consent.source_camera'.tr(),
            subtitle: 'core.consent.source_camera_hint'.tr(),
            onTap: () => Navigator.pop(ctx, ConsentSource.camera),
          ),
          _SourceTile(
            icon: HugeIcons.strokeRoundedImage01,
            title: 'core.consent.source_gallery'.tr(),
            subtitle: 'core.consent.source_gallery_hint'.tr(),
            onTap: () => Navigator.pop(ctx, ConsentSource.gallery),
          ),
          _SourceTile(
            icon: HugeIcons.strokeRoundedPdf01,
            title: 'core.consent.source_pdf'.tr(),
            subtitle: 'core.consent.source_pdf_hint'.tr(),
            onTap: () => Navigator.pop(ctx, ConsentSource.pdf),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
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

/// Elegir una ficha firmada, previsualizarla y subirla (FP-77, FP-78).
///
/// Sirve igual para el director y para el tutor: quien lo usa pasa [onUpload]
/// (cada uno apunta a su endpoint). Subir NUNCA verifica nada; salir de la
/// pantalla a mitad de subida tampoco.
///
/// - Valida tipo y tamaño en el cliente (10 MB; HEIC se rechaza) y no llama a la
///   red si el archivo no sirve.
/// - Si la subida falla muestra el motivo y deja reintentar con el mismo archivo.
/// - Si el consentimiento ya quedó verificado (409) descarta el archivo elegido,
///   muestra el motivo y avisa con [onAlreadyVerified]: la pantalla refresca su
///   estado y deja de ofrecer subir (no tiene sentido reintentar).
/// - [onPendingChanged] avisa cuando hay un archivo elegido sin subir, para que
///   la pantalla no deje confirmar con una ficha vieja mientras tanto.
class ConsentEvidenceUploader extends StatefulWidget {
  const ConsentEvidenceUploader({
    super.key,
    required this.onUpload,
    this.onUploaded,
    this.onPendingChanged,
    this.onAlreadyVerified,
    this.picker = const ConsentEvidencePicker(),
    this.hasExisting = false,
    this.enabled = true,
  });

  final ConsentUploadCallback onUpload;
  final ValueChanged<ConsentEvidenceReceipt>? onUploaded;
  final ValueChanged<bool>? onPendingChanged;

  /// La subida fue rechazada porque el consentimiento ya está verificado.
  final VoidCallback? onAlreadyVerified;
  final ConsentEvidencePicker picker;

  /// Ya hay una ficha vigente: el botón dice "Reemplazar".
  final bool hasExisting;
  final bool enabled;

  @override
  State<ConsentEvidenceUploader> createState() =>
      _ConsentEvidenceUploaderState();
}

class _ConsentEvidenceUploaderState extends State<ConsentEvidenceUploader> {
  ConsentEvidenceLocalFile? _file;
  bool _uploading = false;
  Object? _error;
  bool _pickFailed = false;

  void _setFile(ConsentEvidenceLocalFile? file) {
    final wasPending = _file != null;
    _file = file;
    if ((file != null) != wasPending) {
      widget.onPendingChanged?.call(file != null);
    }
  }

  Future<void> _choose() async {
    final source = await showConsentSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final picked = await widget.picker.pick(source);
      if (picked == null || !mounted) return;
      setState(() {
        _setFile(picked);
        _error = null;
        _pickFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickFailed = true);
    }
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null || _uploading || file.problem != null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    final result = await widget.onUpload(file);
    if (!mounted) return;
    result.fold(
      (failure) {
        final alreadyVerified = isConsentAlreadyVerified(failure);
        setState(() {
          _uploading = false;
          _error = failure;
          // Ya no hay nada que reintentar: se descarta el archivo.
          if (alreadyVerified) _setFile(null);
        });
        if (alreadyVerified) widget.onAlreadyVerified?.call();
      },
      (receipt) {
        setState(() {
          _uploading = false;
          _setFile(null);
        });
        widget.onUploaded?.call(receipt);
      },
    );
  }

  String _problemText(ConsentFileProblem problem) => switch (problem) {
        ConsentFileProblem.unsupportedType =>
          'core.consent.problems.unsupported_type'.tr(),
        ConsentFileProblem.heic => 'core.consent.problems.heic'.tr(),
        ConsentFileProblem.tooLarge => 'core.consent.problems.too_large'.tr(),
        ConsentFileProblem.empty => 'core.consent.problems.empty'.tr(),
      };

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final enabled = widget.enabled && !_uploading;

    if (file == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacButton.outline(
            text: widget.hasExisting
                ? 'core.consent.replace'.tr()
                : 'core.consent.upload'.tr(),
            icon: HugeIcons.strokeRoundedUpload01,
            onPressed: enabled ? _choose : null,
          ),
          if (_pickFailed)
            _ErrorText(message: 'core.consent.errors.pick_failed'.tr()),
          if (isConsentAlreadyVerified(_error))
            _ErrorText(message: consentErrorMessage(_error)),
        ],
      );
    }

    final problem = file.problem;
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilePreview(file: file),
        if (problem != null) _ErrorText(message: _problemText(problem)),
        if (error != null) _ErrorText(message: consentErrorMessage(error)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SacButton.outline(
                text: 'core.consent.change'.tr(),
                onPressed: enabled ? _choose : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SacButton.primary(
                text: error != null
                    ? 'core.consent.retry'.tr()
                    : 'core.consent.upload_action'.tr(),
                icon: HugeIcons.strokeRoundedUpload01,
                isLoading: _uploading,
                onPressed: enabled && problem == null ? _upload : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilePreview extends StatelessWidget {
  const _FilePreview({required this.file});

  final ConsentEvidenceLocalFile file;

  String get _size {
    final mb = file.sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(file.sizeBytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final accent = SacAccent.of(context);

    Widget thumb;
    if (file.isImage && file.problem == null) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(file.path),
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          cacheWidth: 128,
          errorBuilder: (_, __, ___) => _PlaceholderThumb(
            icon: HugeIcons.strokeRoundedImage01,
            color: accent.color,
            background: accent.light,
          ),
        ),
      );
    } else {
      thumb = _PlaceholderThumb(
        icon: file.isPdf
            ? HugeIcons.strokeRoundedPdf01
            : HugeIcons.strokeRoundedFile01,
        color: accent.color,
        background: accent.light,
      );
    }

    return SacCard(
      child: Row(
        children: [
          thumb,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _size,
                  style: textTheme.bodySmall?.copyWith(
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

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({
    required this.icon,
    required this.color,
    required this.background,
  });

  final HugeIconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: HugeIcon(icon: icon, size: 28, color: color)),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.error,
            ),
      ),
    );
  }
}
