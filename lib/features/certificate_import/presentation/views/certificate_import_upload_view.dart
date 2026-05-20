import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../data/datasources/certificate_import_remote_data_source.dart';
import '../../domain/usecases/create_certificate_import_batch.dart';
import '../providers/certificate_import_providers.dart';

class CertificateImportUploadRouteView extends ConsumerWidget {
  const CertificateImportUploadRouteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CertificateImportUploadView(
      onCreateMockUpload: () async {
        final result =
            await ref.read(createCertificateImportBatchProvider).call(
                  const CreateCertificateImportBatchParams(
                    files: [
                      CertificateImportFilePayload(
                        url: 'mock://certificate-import/pending-uploader.jpg',
                        name: 'comprobante-pendiente.jpg',
                        type: 'image/jpeg',
                      ),
                    ],
                  ),
                );
        result.fold(
          (failure) => throw Exception(failure.message),
          (batch) => context.push(
            RouteNames.certificateImportProcessingPath(batch.id),
          ),
        );
      },
    );
  }
}

class CertificateImportUploadView extends StatefulWidget {
  const CertificateImportUploadView({
    super.key,
    this.onCreateMockUpload,
    this.onPickCamera,
    this.onPickFile,
  });

  final Future<void> Function()? onCreateMockUpload;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickFile;

  @override
  State<CertificateImportUploadView> createState() =>
      _CertificateImportUploadViewState();
}

class _CertificateImportUploadViewState
    extends State<CertificateImportUploadView> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Carga por certificado')),
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
                        'Podés mezclar especialidades y clases. SACDIA detecta candidatos, pero vos confirmás antes de enviar.',
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
                        icon: Icons.upload_rounded,
                        isLoading: _loading,
                        onPressed: _loading ? null : _createMockUpload,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SacButton.outline(
                              text: 'Tomar foto',
                              icon: Icons.camera_alt_outlined,
                              onPressed:
                                  widget.onPickCamera ?? _createMockUpload,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SacButton.outline(
                              text: 'Elegir archivo',
                              icon: Icons.folder_outlined,
                              onPressed: widget.onPickFile ?? _createMockUpload,
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

  Future<void> _createMockUpload() async {
    if (widget.onCreateMockUpload == null) {
      setState(() => _error =
          'Uploader real pendiente: seam preparado para metadata del archivo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onCreateMockUpload!();
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
            'Subí tus comprobantes y los leemos por vos',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'OCR asistido para honores y clases. Menos tipeo, misma responsabilidad: revisar antes de enviar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
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
