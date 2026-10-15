import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../error/certificate_import_error_mapper.dart';

/// Why the review has no rows (state F), decided from `ocr_state`.
enum ImportReviewEmptyKind {
  /// Reading finished without rows, or the backend sends no state (R6).
  empty,

  /// Reading failed; [ImportReviewEmpty.error] carries the copy.
  failed,

  /// `pending` or `running`: the screen refreshes by itself.
  reading,

  /// OCR was never requested for this batch (manual batch).
  none,
}

/// Empty review: one title, one body and one main way out. A failed reading
/// only offers a retry when retrying can help (no useless retry for a
/// protected PDF).
class ImportReviewEmpty extends StatelessWidget {
  const ImportReviewEmpty({
    super.key,
    required this.kind,
    required this.onAdd,
    this.error,
    this.onRetryRead,
    this.onChooseOtherFile,
  });

  final ImportReviewEmptyKind kind;
  final CertificateImportErrorInfo? error;
  final VoidCallback onAdd;
  final VoidCallback? onRetryRead;
  final VoidCallback? onChooseOtherFile;

  /// Kinds where reading again can succeed.
  static const _retryable = {
    CertificateImportErrorKind.ocrFailed,
    CertificateImportErrorKind.offline,
    CertificateImportErrorKind.timeout,
    CertificateImportErrorKind.unknown,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final info = error;
    final failed = kind == ImportReviewEmptyKind.failed && info != null;
    final slug = switch (kind) {
      ImportReviewEmptyKind.empty => 'empty',
      ImportReviewEmptyKind.reading => 'reading',
      _ => 'none',
    };
    final title = failed
        ? info.title
        : 'certificate_import.review.empty_${slug}_title'.tr();
    final body = failed
        ? info.body
        : 'certificate_import.review.empty_${slug}_body'.tr();
    final retry =
        failed && onRetryRead != null && _retryable.contains(info.kind);
    final other = failed &&
        onChooseOtherFile != null &&
        info.action == CertificateImportErrorAction.chooseOtherFile;
    final addIsMain = !retry && !other;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: [
            if (kind == ImportReviewEmptyKind.reading)
              const SacLoading()
            else
              HugeIcon(
                icon: failed
                    ? HugeIcons.strokeRoundedAlert02
                    : HugeIcons.strokeRoundedDocumentValidation,
                size: 56,
                color: failed ? c.error : c.textTertiary,
              ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 24),
            if (retry)
              SacButton.primary(
                text: 'certificate_import.review.retry_read'.tr(),
                onPressed: onRetryRead,
              ),
            if (other)
              SacButton.primary(
                text: 'certificate_import.errors.choose_other'.tr(),
                onPressed: onChooseOtherFile,
              ),
            if (addIsMain)
              SacButton.primary(
                text: 'certificate_import.review.add_row'.tr(),
                onPressed: onAdd,
              )
            else
              SacButton.ghost(
                text: 'certificate_import.review.add_row'.tr(),
                onPressed: onAdd,
              ),
          ],
        ),
      ),
    );
  }
}
