import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/sac_colors.dart';
import '../providers/insurance_providers.dart';

/// Resumen de cobertura estilo Health: cifra grande, barra fina,
/// stats tappable que sustituyen la fila de FilterChips.
class InsuranceSummaryHeader extends StatelessWidget {
  final InsuranceSummary summary;
  final InsuranceStatusFilter selectedFilter;
  final ValueChanged<InsuranceStatusFilter> onFilterChanged;

  const InsuranceSummaryHeader({
    super.key,
    required this.summary,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final coverage = summary.coveragePercent;
    final coverageColor = _coverageColor(context, coverage);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${coverage.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: coverageColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  height: 1.05,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            'insurance.view.coverage_title'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'insurance.view.coverage_of'.tr(namedArgs: {
              'insured': '${summary.asegurados}',
              'total': '${summary.total}',
            }),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textTertiary,
                  fontSize: 13,
                ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: coverage / 100,
              backgroundColor: c.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(coverageColor),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _FilterStat(
                label: 'insurance.summary.total'.tr(),
                count: summary.total,
                color: c.text,
                selected: selectedFilter == InsuranceStatusFilter.todos,
                onTap: () => _select(InsuranceStatusFilter.todos),
              ),
              _FilterStat(
                label: 'insurance.summary.insured'.tr(),
                count: summary.asegurados,
                color: c.success,
                selected: selectedFilter == InsuranceStatusFilter.asegurado,
                onTap: () => _select(InsuranceStatusFilter.asegurado),
              ),
              if (summary.vencidos > 0 ||
                  selectedFilter == InsuranceStatusFilter.vencido)
                _FilterStat(
                  label: 'insurance.summary.expired'.tr(),
                  count: summary.vencidos,
                  color: c.onWarning,
                  selected: selectedFilter == InsuranceStatusFilter.vencido,
                  onTap: () => _select(InsuranceStatusFilter.vencido),
                ),
              if (summary.sinSeguro > 0 ||
                  selectedFilter == InsuranceStatusFilter.sinSeguro)
                _FilterStat(
                  label: 'insurance.summary.uninsured'.tr(),
                  count: summary.sinSeguro,
                  color: c.error,
                  selected: selectedFilter == InsuranceStatusFilter.sinSeguro,
                  onTap: () => _select(InsuranceStatusFilter.sinSeguro),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _select(InsuranceStatusFilter filter) {
    HapticFeedback.selectionClick();
    if (filter == selectedFilter && filter != InsuranceStatusFilter.todos) {
      onFilterChanged(InsuranceStatusFilter.todos);
      return;
    }
    onFilterChanged(filter);
  }

  Color _coverageColor(BuildContext context, double pct) {
    final c = context.sac;
    if (pct >= 80) return c.success;
    if (pct >= 50) return c.onWarning;
    return c.error;
  }
}

class _FilterStat extends StatefulWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterStat({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterStat> createState() => _FilterStatState();
}

class _FilterStatState extends State<_FilterStat> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final color = widget.selected ? widget.color : c.textTertiary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? 0.97 : 1,
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedOpacity(
                  opacity: widget.selected ? 1 : 0,
                  duration: SacMotion.standard,
                  curve: SacMotion.easeOut,
                  child: Container(
                    height: 2,
                    width: 18,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
