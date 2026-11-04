import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_submission_readiness.dart';

/// Sticky bottom bar of the in-progress honor screen.
///
/// While the member can still submit it says what is missing and offers
/// "Enviar a revisión" (disabled until [HonorSubmissionReadiness.canSubmit]).
/// Under review it shows the "En revisión" badge and no button.
class HonorSubmitBar extends StatelessWidget {
  const HonorSubmitBar({
    super.key,
    required this.readiness,
    required this.bandColor,
    required this.isUnderReview,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final HonorSubmissionReadiness readiness;
  final Color bandColor;
  final bool isUnderReview;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  /// "Te falta: 3 requisitos y la fecha de finalización" or, when nothing is
  /// missing, "Todo listo para enviar".
  static String summary(HonorSubmissionReadiness readiness) {
    final parts = <String>[
      if (readiness.unsatisfiedCount > 0)
        'honors.requirements.missing_requirements'
            .plural(readiness.unsatisfiedCount),
      if (readiness.missingEvidenceCount > 0)
        'honors.requirements.missing_evidences'
            .plural(readiness.missingEvidenceCount),
      if (!readiness.hasCompletionDate) 'honors.requirements.missing_date'.tr(),
    ];
    if (parts.isEmpty) return 'honors.requirements.ready_to_send'.tr();
    final joined = parts.length == 1
        ? parts.first
        : '${parts.sublist(0, parts.length - 1).join(', ')}'
            '${'honors.requirements.list_and'.tr()}${parts.last}';
    return 'honors.requirements.missing_intro'.tr(namedArgs: {'items': joined});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: const ValueKey('honor-submit-bar'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
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
                summary(readiness),
                key: const ValueKey('honor-submit-summary'),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            SacButton.primary(
              key: const ValueKey('honor-submit-button'),
              text: 'honors.detail.send_review_cta'.tr(),
              icon: HugeIcons.strokeRoundedSent,
              isLoading: isSubmitting,
              backgroundColor: bandColor,
              textColor: Colors.white,
              onPressed:
                  (readiness.canSubmit && !isSubmitting) ? onSubmit : null,
            ),
          ],
        ],
      ),
    );
  }
}
