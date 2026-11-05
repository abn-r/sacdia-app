import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_submission_readiness.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_action_bar.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_band_scaffold.dart';

/// Sticky bottom bar of the in-progress honor screens (in-app and external).
///
/// While the member can still submit it shows [summary] (what is missing) and
/// offers "Enviar a revisión", disabled until [canSubmit]. Under review it
/// shows the "En revisión" badge and no button.
///
/// The completion date lives in "Información", out of sight, so the bar
/// leads to it ([onPickDate]): when the date is the only thing missing
/// ([onlyDateMissing]) the main button opens the date picker; when other
/// parts are missing too, a link under the summary does.
class HonorSubmitBar extends StatelessWidget {
  const HonorSubmitBar({
    super.key,
    required this.summary,
    required this.canSubmit,
    required this.bandColor,
    required this.isUnderReview,
    required this.isSubmitting,
    required this.onSubmit,
    this.onPickDate,
    this.onlyDateMissing = false,
  });

  /// "Te falta: …" or "Todo listo para enviar".
  final String summary;
  final bool canSubmit;
  final Color bandColor;
  final bool isUnderReview;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  /// Opens the completion date picker; null when the date is set.
  final VoidCallback? onPickDate;

  /// Everything but the date is ready.
  final bool onlyDateMissing;

  /// "Te falta: 3 requisitos y la fecha de finalización" or, when nothing is
  /// missing, "Todo listo para enviar".
  static String summaryFor(HonorSubmissionReadiness readiness) {
    return fromMissing([
      if (readiness.unsatisfiedCount > 0)
        'honors.requirements.missing_requirements'
            .plural(readiness.unsatisfiedCount),
      if (readiness.missingEvidenceCount > 0)
        'honors.requirements.missing_evidences'
            .plural(readiness.missingEvidenceCount),
      if (!readiness.hasCompletionDate) 'honors.requirements.missing_date'.tr(),
    ]);
  }

  /// External honors: "Te falta: el formato completado, una evidencia general
  /// y la fecha de finalización".
  static String summaryForExternal(ExternalSubmissionReadiness readiness) {
    return fromMissing([
      if (!readiness.hasFormat) 'honors.evidence.missing_format'.tr(),
      if (!readiness.hasGeneralEvidence)
        'honors.evidence.missing_general_evidence'.tr(),
      if (!readiness.hasCompletionDate) 'honors.requirements.missing_date'.tr(),
    ]);
  }

  /// "Te falta: a, b y c" for the [missing] parts, or "Todo listo para
  /// enviar" when there are none.
  static String fromMissing(List<String> missing) {
    if (missing.isEmpty) return 'honors.requirements.ready_to_send'.tr();
    final joined = missing.length == 1
        ? missing.first
        : '${missing.sublist(0, missing.length - 1).join(', ')}'
            '${'honors.requirements.list_and'.tr()}${missing.last}';
    return 'honors.requirements.missing_intro'.tr(namedArgs: {'items': joined});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;

    return HonorActionBar(
      key: const ValueKey('honor-submit-bar'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isUnderReview) ...[
            Center(
              child: SacBadge.info(
                label: 'honors.detail.under_review_cta'.tr(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'honors.requirements.under_review_hint'.tr(),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ] else ...[
            Semantics(
              liveRegion: true,
              child: Text(
                summary,
                key: const ValueKey('honor-submit-summary'),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ),
            if (onPickDate != null && !onlyDateMissing)
              Center(
                child: SacButton.text(
                  key: const ValueKey('honor-submit-pick-date-link'),
                  text: 'honors.requirements.add_date_cta'.tr(),
                  icon: HugeIcons.strokeRoundedCalendar03,
                  color: honorOnTint(context, bandColor),
                  onPressed: onPickDate,
                ),
              )
            else
              const SizedBox(height: 10),
            if (onPickDate != null && onlyDateMissing)
              SacButton.primary(
                key: const ValueKey('honor-submit-pick-date'),
                text: 'honors.requirements.add_date_cta'.tr(),
                icon: HugeIcons.strokeRoundedCalendar03,
                backgroundColor: bandColor,
                textColor: Colors.white,
                onPressed: onPickDate,
              )
            else
              SacButton.primary(
                key: const ValueKey('honor-submit-button'),
                text: 'honors.detail.send_review_cta'.tr(),
                icon: HugeIcons.strokeRoundedSent,
                isLoading: isSubmitting,
                backgroundColor: bandColor,
                textColor: Colors.white,
                onPressed: (canSubmit && !isSubmitting) ? onSubmit : null,
              ),
          ],
        ],
      ),
    );
  }
}
