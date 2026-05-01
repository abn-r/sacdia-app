import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../providers/insurance_providers.dart';

/// Header de resumen de cobertura de seguros del club.
///
/// Sigue el design system "Scout Vibrante":
/// fondo de surface con borde sutil, icono en contenedor de acento,
/// sin gradientes, tokens de color semánticos via `context.sac`.
class InsuranceSummaryHeader extends StatelessWidget {
  final InsuranceSummary summary;

  const InsuranceSummaryHeader({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final coverage = summary.coveragePercent;
    final coverageColor = _coverageColor(coverage);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              // Icon container — standard app pattern
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedShield01,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Title
              Text(
                'insurance.view.coverage_title'.tr(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                    ),
              ),

              const Spacer(),

              // Coverage percentage badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: coverageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: coverageColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${coverage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: coverageColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: coverage / 100,
              backgroundColor: c.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(coverageColor),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 12),

          // Stats pills row
          Row(
            children: [
              _StatPill(
                label: 'insurance.summary.total'.tr(),
                count: summary.total,
                color: c.textSecondary,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: 'insurance.summary.insured'.tr(),
                count: summary.asegurados,
                color: AppColors.secondary,
              ),
              if (summary.vencidos > 0) ...[
                const SizedBox(width: 8),
                _StatPill(
                  label: 'insurance.summary.expired'.tr(),
                  count: summary.vencidos,
                  color: AppColors.accent,
                ),
              ],
              if (summary.sinSeguro > 0) ...[
                const SizedBox(width: 8),
                _StatPill(
                  label: 'insurance.summary.uninsured'.tr(),
                  count: summary.sinSeguro,
                  color: AppColors.error,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _coverageColor(double pct) {
    if (pct >= 80) return AppColors.secondary;
    if (pct >= 50) return AppColors.accent;
    return AppColors.error;
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
