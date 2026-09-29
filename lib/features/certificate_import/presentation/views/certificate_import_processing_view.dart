import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

/// OCR real no está autorizado en este cliente: no se invoca process-ocr.
/// El usuario completa el expediente a mano.
class CertificateImportProcessingRouteView extends ConsumerWidget {
  const CertificateImportProcessingRouteView(
      {super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CertificateImportProcessingView(
      batchId: batchId,
      autoStart: false,
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
    if (widget.autoStart && widget.onStartOcr != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ocrUnavailable = widget.onStartOcr == null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'certificate_import.processing.title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => ListView(
            padding: SacTopBar.paddingBelowBar(
                context, const EdgeInsets.fromLTRB(20, 16, 20, 28)),
            children: [
              SacCard(
                child: Column(
                  children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedDocumentValidation,
                        size: 72,
                        color: c.info),
                    const SizedBox(height: 16),
                    Text(
                      ocrUnavailable
                          ? 'certificate_import.processing.manual_title'.tr()
                          : _error == null
                              ? 'certificate_import.processing.running_title'
                                  .tr()
                              : 'certificate_import.processing.error_title'
                                  .tr(),
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: c.text,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ocrUnavailable
                          ? 'certificate_import.processing.manual_body'.tr()
                          : _error == null
                              ? 'certificate_import.processing.running_body'
                                  .tr()
                              : 'certificate_import.processing.error_body'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Step(
                  label: 'certificate_import.processing.step_upload'.tr(),
                  done: true),
              _Step(
                  label: 'certificate_import.processing.step_ocr'.tr(),
                  active: _running && _error == null && !ocrUnavailable),
              _Step(
                  label: 'certificate_import.processing.step_results'.tr(),
                  active: _running && _error == null && !ocrUnavailable),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: c.error)),
              ],
              const SizedBox(height: 22),
              SacButton.outline(
                text: 'certificate_import.processing.manual'.tr(),
                icon: HugeIcons.strokeRoundedNoteEdit,
                onPressed: widget.onManualFallback,
              ),
              if (!ocrUnavailable) ...[
                const SizedBox(height: 10),
                SacButton.ghost(
                  text: 'certificate_import.processing.retry'.tr(),
                  onPressed: _running ? null : _start,
                ),
              ],
            ],
          ),
        ),
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
          HugeIcon(
              icon: done
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedCircle,
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
