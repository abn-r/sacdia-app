import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/insurance_overview.dart';
import '../utils/insurance_formatting.dart';
import 'insurance_ui.dart';

/// "Con seguro 2027": how many are covered, the three-segment bar and, when
/// there is a cost, what it is and until when it can be paid.
class InsuranceSummaryBox extends StatelessWidget {
  const InsuranceSummaryBox({super.key, required this.overview});

  final InsuranceOverview overview;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final counts = overview.counts;
    final cycle = overview.cycle;
    final deadline = cycle?.purchaseDeadline;
    final year = overview.year?.label ?? '';
    // Like the mockup: "faltan" = nobody is handling them yet (no order).
    final missing = counts.uninsured;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SacSummaryBox(
        color: c.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('insurance.summary.label', namedArgs: {'year': year}),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              key: const ValueKey('insurance-summary-count'),
              TextSpan(
                children: [
                  TextSpan(
                    text: tr(
                      'insurance.summary.covered_of_total',
                      namedArgs: {
                        'covered': '${counts.covered}',
                        'total': '${counts.total}',
                      },
                    ),
                    style: TextStyle(
                      fontSize: SacFontSize.displayMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: c.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (missing > 0)
                    TextSpan(
                      text: '  ·  ${tr(
                        'insurance.summary.missing',
                        namedArgs: {'count': '$missing'},
                      )}',
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SacStatusBar.counts(
              counts: StatusCounts(
                validated: counts.covered,
                review: counts.inProcess,
                pending: counts.uninsured,
              ),
              countLabels: SacStatusCountLabels(
                validated: tr(
                  'insurance.summary.legend_covered',
                  namedArgs: {'count': '${counts.covered}'},
                ),
                review: tr(
                  'insurance.summary.legend_in_process',
                  namedArgs: {'count': '${counts.inProcess}'},
                ),
                rejected: '',
                pending: tr(
                  'insurance.summary.legend_uninsured',
                  namedArgs: {'count': '${counts.uninsured}'},
                ),
              ),
            ),
            if (cycle != null) ...[
              const SizedBox(height: 14),
              Divider(height: 1, thickness: 1, color: c.border),
              _Kv(
                label: tr('insurance.summary.unit_cost'),
                value: SacMoney.fromCentavos(cycle.unitCostCentavos),
              ),
              if (deadline != null) ...[
                Divider(height: 1, thickness: 1, color: c.border),
                _Kv(
                  label: tr('insurance.summary.pay_before'),
                  value: insuranceFullDate(context, deadline),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A divided line of the box: the cost, the deadline.
class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: InsuranceBoxLine(label: label, value: value),
      );
}
