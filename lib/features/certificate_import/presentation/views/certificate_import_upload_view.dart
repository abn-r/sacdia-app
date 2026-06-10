import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/certificate_import_payloads.dart';
import '../../domain/usecases/create_certificate_import_batch.dart';
import '../providers/certificate_import_providers.dart';
import '../widgets/certificate_import_back_button.dart';

typedef CertificateImportSubmit = Future<void> Function(
    List<CertificateImportFilePayload> files);
typedef CertificateImportProofPicker = Future<CertificateImportFilePayload?>
    Function();

class CertificateImportUploadRouteView extends ConsumerWidget {
  const CertificateImportUploadRouteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CertificateImportUploadView(
      onSubmitProofs: (files) async {
        final result =
            await ref.read(createCertificateImportBatchProvider).call(
                  CreateCertificateImportBatchParams(files: files),
                );
        result.fold(
          (failure) => throw Exception(failure.message),
          (batch) => context.push(
            RouteNames.certificateImportProcessingPath(batch.id),
          ),
        );
      },
      onPickCamera: _pickCameraProof,
      onPickFile: _pickFileProof,
    );
  }

  static Future<CertificateImportFilePayload?> _pickCameraProof() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (image == null) return null;

    return CertificateImportFilePayload(
      url: image.path,
      name: image.name.isNotEmpty ? image.name : 'comprobante.jpg',
      type: image.mimeType ?? lookupMimeType(image.path) ?? 'image/jpeg',
    );
  }

  static Future<CertificateImportFilePayload?> _pickFileProof() async {
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

    return CertificateImportFilePayload(
      url: path,
      name: file.name,
      type: lookupMimeType(path) ??
          _mimeTypeFromExtension(file.extension) ??
          'application/octet-stream',
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

class CertificateImportUploadView extends StatefulWidget {
  const CertificateImportUploadView({
    super.key,
    this.onSubmitProofs,
    this.onPickCamera,
    this.onPickFile,
  });

  final CertificateImportSubmit? onSubmitProofs;
  final CertificateImportProofPicker? onPickCamera;
  final CertificateImportProofPicker? onPickFile;

  @override
  State<CertificateImportUploadView> createState() =>
      _CertificateImportUploadViewState();
}

class _CertificateImportUploadViewState
    extends State<CertificateImportUploadView> {
  bool _loading = false;
  bool _picking = false;
  String? _error;
  List<CertificateImportFilePayload> _selectedFiles = const [];

  bool get _hasFilesToAnalyze => _selectedFiles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const CertificateImportBackButton(
          fallbackLocation: RouteNames.homeProfile,
        ),
        title: const Text('Carga por certificado'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 190),
            children: [
              _UploadHero(),
              const SizedBox(height: 14),
              SacCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: c.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Puedes mezclar especialidades y clases. SACDIA detecta candidatos; confirma los datos antes de enviar.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                _SelectedProofCard(files: _selectedFiles),
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
                      SacButton.primary(
                        text: 'Subir comprobante',
                        icon: HugeIcons.strokeRoundedFileUpload,
                        isLoading: _loading,
                        isEnabled: _hasFilesToAnalyze,
                        onPressed:
                            _loading || !_hasFilesToAnalyze ? null : _submit,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SacButton.outline(
                              text: 'Tomar foto',
                              icon: HugeIcons.strokeRoundedCamera01,
                              isLoading: _picking,
                              onPressed: _picking
                                  ? null
                                  : () => _pickProof(widget.onPickCamera),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SacButton.outline(
                              text: 'Elegir archivo',
                              icon: HugeIcons.strokeRoundedFolder01,
                              isLoading: _picking,
                              onPressed: _picking
                                  ? null
                                  : () => _pickProof(widget.onPickFile),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProof(CertificateImportProofPicker? picker) async {
    if (picker == null) {
      setState(() => _error = 'No se pudo abrir el selector de comprobantes.');
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

      setState(() {
        _selectedFiles = [file];
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (!_hasFilesToAnalyze) return;
    if (widget.onSubmitProofs == null) {
      setState(
        () =>
            _error = 'No hay un proceso configurado para enviar comprobantes.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmitProofs!(_selectedFiles);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                    child: Icon(Icons.auto_awesome_rounded, color: c.warning),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Carga tus comprobantes y SACDIA los leerá',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'OCR asistido para honores y clases. Menos captura manual, misma responsabilidad: revisar antes de enviar.',
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
  const _SelectedProofCard({required this.files});

  final List<CertificateImportFilePayload> files;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final fileCount = files.length;
    final firstName = files.first.name;

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
                  fileCount == 1
                      ? 'Comprobante seleccionado'
                      : '$fileCount comprobantes seleccionados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  firstName,
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
