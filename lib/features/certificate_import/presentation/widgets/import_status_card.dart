import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../error/certificate_import_error_mapper.dart';

/// Visual weight of an [ImportStatusCard].
enum ImportStatusTone { neutral, error, info }

/// Icon, title, body and up to two actions for upload problems (states C0 to
/// C3 of the redesign): invalid local file, no connection, bad PDF, busy queue.
class ImportStatusCard extends StatelessWidget {
  const ImportStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tone = ImportStatusTone.error,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Card for a mapped failure. Retryable errors offer "retry" plus "change
  /// file"; errors caused by the file only offer "choose another file".
  factory ImportStatusCard.fromError(
    CertificateImportErrorInfo info, {
    VoidCallback? onRetry,
    VoidCallback? onChooseOther,
  }) {
    final isFileProblem =
        info.action == CertificateImportErrorAction.chooseOtherFile;
    final canRetry = info.action == CertificateImportErrorAction.retry;
    return ImportStatusCard(
      key: ValueKey('import-status-${info.kind.name}'),
      icon: _iconFor(info.kind),
      tone: _toneFor(info.kind),
      title: info.title,
      body: info.body,
      primaryLabel: canRetry
          ? 'certificate_import.errors.retry'.tr()
          : isFileProblem
              ? 'certificate_import.errors.choose_other'.tr()
              : null,
      onPrimary: canRetry ? onRetry : (isFileProblem ? onChooseOther : null),
      secondaryLabel:
          canRetry ? 'certificate_import.errors.change_file'.tr() : null,
      onSecondary: canRetry ? onChooseOther : null,
    );
  }

  final HugeIconData icon;
  final String title;
  final String body;
  final ImportStatusTone tone;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  static HugeIconData _iconFor(CertificateImportErrorKind kind) {
    switch (kind) {
      case CertificateImportErrorKind.offline:
      case CertificateImportErrorKind.timeout:
        return HugeIcons.strokeRoundedWifiDisconnected01;
      case CertificateImportErrorKind.pdfBusy:
        return HugeIcons.strokeRoundedHourglass;
      case CertificateImportErrorKind.pdfTooManyPages:
      case CertificateImportErrorKind.pdfEncrypted:
      case CertificateImportErrorKind.pdfInvalid:
      case CertificateImportErrorKind.ocrUnsupportedType:
      case CertificateImportErrorKind.ocrFileTooLarge:
        return HugeIcons.strokeRoundedFileRemove;
      default:
        return HugeIcons.strokeRoundedAlert02;
    }
  }

  static ImportStatusTone _toneFor(CertificateImportErrorKind kind) {
    switch (kind) {
      case CertificateImportErrorKind.offline:
      case CertificateImportErrorKind.timeout:
        return ImportStatusTone.neutral;
      case CertificateImportErrorKind.pdfBusy:
        return ImportStatusTone.info;
      default:
        return ImportStatusTone.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = switch (tone) {
      ImportStatusTone.neutral => c.textSecondary,
      ImportStatusTone.error => c.error,
      ImportStatusTone.info => c.info,
    };
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: SacCard(
        borderColor: tone == ImportStatusTone.error ? c.error : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HugeIcon(icon: icon, color: accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style:
                            text.bodyMedium?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (primaryLabel != null || secondaryLabel != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (primaryLabel != null)
                    SacButton(
                      text: primaryLabel!,
                      variant: SacButtonVariant.outline,
                      size: SacButtonSize.small,
                      fullWidth: false,
                      onPressed: onPrimary,
                    ),
                  if (secondaryLabel != null)
                    SacButton(
                      text: secondaryLabel!,
                      variant: SacButtonVariant.ghost,
                      size: SacButtonSize.small,
                      fullWidth: false,
                      onPressed: onSecondary,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
