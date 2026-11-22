import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

import '../controllers/certificate_import_upload_controller.dart';

/// What the screen shows while a proof is sent and read: ONE state panel that
/// goes from "Subiendo 64 %" (the real upload progress) to "Leyendo tu
/// comprobante", and below it the "Encontrado" group as skeleton rows that the
/// review fills in later.
///
/// The percentage updates in place; only a change of phase animates the
/// panel. A screen reader hears 0, 25, 50, 75 and 100 % so it is not flooded.
class ImportUploadProgress extends StatelessWidget {
  const ImportUploadProgress({
    super.key,
    this.phase,
    this.progress,
    this.slow,
  });

  final ValueListenable<CertificateImportUploadPhase>? phase;
  final ValueListenable<double>? progress;
  final ValueListenable<bool>? slow;

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
    final announced = percent ~/ 25 * 25;
    String uploadingText(int value) => value > 0
        ? 'certificate_import.upload.panel_uploading'
            .tr(namedArgs: {'percent': '$value'})
        : 'certificate_import.upload.panel_uploading_start'.tr();
    final title = reading
        ? 'certificate_import.upload.panel_reading'.tr()
        : uploadingText(percent);
    final isSlow = slow?.value ?? false;
    final message = reading && isSlow
        ? 'certificate_import.upload.reading_slow'.tr()
        : 'certificate_import.upload.panel_hint'.tr();
    final style = SacStatusStyle.of(
      context,
      SacStatusKind.review,
      label: title,
      icon: reading
          ? HugeIcons.strokeRoundedMagicWand01
          : HugeIcons.strokeRoundedFileUpload,
    );

    return Column(
      key: const ValueKey('certificate-import-upload-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Semantics(
            liveRegion: true,
            child: SacStatePanel(
              style: style,
              title: title,
              message: message,
              stateKey: reading ? 'reading' : 'uploading',
              semanticsLabel: [
                reading ? title : uploadingText(announced),
                message
              ].join('. '),
            ),
          ),
        ),
        // Vision reports no progress, so no bar while reading.
        if (!reading && progress != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: ExcludeSemantics(
              child: SacTweenedBar(
                value: progress!.value,
                color: style.solid,
                backgroundColor: c.border,
              ),
            ),
          ),
        SacGroupedSection(
          label: 'certificate_import.upload.found'.tr(),
          // No count: nothing is found yet.
          action: const SizedBox.shrink(),
          children: const [
            _SkeletonRow(),
            _SkeletonRow(),
            _SkeletonRow(),
          ],
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const SacShimmer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            SacSkeletonBox(
              width: 32,
              height: 32,
              radius: AppTheme.radiusSM,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.7,
                    child: SacSkeletonBox(height: 12),
                  ),
                  SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.4,
                    child: SacSkeletonBox(height: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
