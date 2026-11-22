import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_tweened_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';

/// "Filas listas · 3 de 4 · falta 1" with a progress bar, in the soft summary
/// box that opens the review.
class ImportReviewSummary extends StatelessWidget {
  const ImportReviewSummary({
    super.key,
    required this.total,
    required this.readyCount,
  });

  final int total;
  final int readyCount;

  int get _missing => total - readyCount;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final value = 'certificate_import.review.ready_count'
        .tr(namedArgs: {'ready': '$readyCount', 'total': '$total'});
    final suffix = _missing <= 0
        ? null
        : (_missing == 1
                ? 'certificate_import.review.missing_one'
                : 'certificate_import.review.missing_other')
            .tr(namedArgs: {'count': '$_missing'});
    final label = 'certificate_import.review.summary_label'.tr();
    return Semantics(
      container: true,
      label: [label, value, if (suffix != null) suffix].join('. '),
      excludeSemantics: true,
      child: SacSummaryBox(
        color: c.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: SacFontSize.displayMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: c.text,
                    ),
                  ),
                  if (suffix != null)
                    TextSpan(
                      text: '  $suffix',
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SacTweenedBar(
              value: total == 0 ? 0 : readyCount / total,
              color: c.success,
              backgroundColor: c.border,
              minHeight: 6,
            ),
          ],
        ),
      ),
    );
  }
}
