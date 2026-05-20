import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../providers/certificate_import_providers.dart';

class CertificateImportProcessingRouteView extends ConsumerWidget {
  const CertificateImportProcessingRouteView(
      {super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CertificateImportProcessingView(
      batchId: batchId,
      onStartOcr: () async {
        final result =
            await ref.read(processCertificateImportOcrProvider).call(batchId);
        result.fold(
          (failure) => throw Exception(failure.message),
          (_) => context.go(RouteNames.certificateImportReviewPath(batchId)),
        );
      },
      onManualFallback: () =>
          context.go(RouteNames.certificateImportReviewPath(batchId)),
    );
  }
}

class CertificateImportProcessingView extends StatefulWidget {
  const CertificateImportProcessingView({
    super.key,
    required this.batchId,
    this.autoStart = true,
    this.onStartOcr,
    this.onManualFallback,
  });

  final String batchId;
  final bool autoStart;
  final Future<void> Function()? onStartOcr;
  final VoidCallback? onManualFallback;

  @override
  State<CertificateImportProcessingView> createState() =>
      _CertificateImportProcessingViewState();
}

class _CertificateImportProcessingViewState
    extends State<CertificateImportProcessingView> {
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Leyendo comprobante')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          SacCard(
            child: Column(
              children: [
                Icon(Icons.document_scanner_rounded, size: 72, color: c.info),
                const SizedBox(height: 16),
                Text(
                  _error == null
                      ? 'Estamos leyendo tu comprobante'
                      : 'No pudimos leer todo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error == null
                      ? 'Extraemos honores, clases y fechas para que confirmes los datos.'
                      : 'Podés reintentar OCR o completar los datos manualmente. No te dejamos en un callejón sin salida.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Step(label: 'Subiendo archivo', done: true),
          _Step(label: 'Leyendo texto', active: _running && _error == null),
          _Step(
              label: 'Preparando resultados',
              active: _running && _error == null),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: c.error)),
          ],
          const SizedBox(height: 22),
          SacButton.outline(
            text: 'Completar manualmente',
            icon: Icons.edit_note_rounded,
            onPressed: widget.onManualFallback,
          ),
          const SizedBox(height: 10),
          SacButton.ghost(
            text: 'Reintentar lectura',
            onPressed: _running ? null : _start,
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    if (widget.onStartOcr == null) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await widget.onStartOcr!();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, this.done = false, this.active = false});

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = done
        ? c.success
        : active
            ? c.warning
            : c.border;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (active)
            SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: c.warning),
            ),
        ],
      ),
    );
  }
}
