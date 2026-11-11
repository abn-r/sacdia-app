import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_skeleton.dart';
import '../../../../core/widgets/sac_tweened_bar.dart';
import '../../domain/entities/category_breakdown.dart';
import '../providers/finances_providers.dart';
import '../theme/finance_tokens.dart';

/// Sección «Por categoría» de Finanzas: ingresos y egresos del mes
/// seleccionado agrupados por categoría, con total, cantidad de movimientos y
/// una barra proporcional al total de su grupo.
class CategoryBreakdownSection extends ConsumerWidget {
  const CategoryBreakdownSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeByCategoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              'finances.by_category.title'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.titleMedium,
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
            ),
          ),
        ),
        async.when(
          loading: () => const _BreakdownSkeleton(),
          error: (e, _) => SacErrorState.inline(
            message: userErrorMessage(e),
            onRetry: () => invalidateFinanceData(ref.invalidate),
          ),
          data: (breakdown) {
            if (breakdown == null || breakdown.isEmpty) {
              return SacEmptyState.inline(
                title: 'finances.by_category.empty'.tr(),
              );
            }
            return Column(
              children: [
                if (breakdown.income.isNotEmpty)
                  _CategoryGroup(
                    isIncome: true,
                    items: breakdown.income,
                    groupTotal: breakdown.totalIncome,
                  ),
                if (breakdown.expenses.isNotEmpty)
                  _CategoryGroup(
                    isIncome: false,
                    items: breakdown.expenses,
                    groupTotal: breakdown.totalExpenses,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Group (income or expenses) ─────────────────────────────────────────────────

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.isIncome,
    required this.items,
    required this.groupTotal,
  });

  final bool isIncome;
  final List<CategoryTotal> items;
  final double groupTotal;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textColor = isIncome
        ? FinanceTokens.incomeText(context)
        : FinanceTokens.expenseText(context);
    final title = isIncome
        ? 'finances.by_category.income'.tr()
        : 'finances.by_category.expenses'.tr();
    // The group header carries the meaning with icon + text + sign, never the
    // color alone.
    final totalLabel = SacMoney.format(
      isIncome ? groupTotal : -groupTotal,
      signed: true,
    );

    return SacCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: '$title, $totalLabel',
            excludeSemantics: true,
            child: Row(
              children: [
                HugeIcon(
                  icon: isIncome
                      ? HugeIcons.strokeRoundedArrowDown01
                      : HugeIcons.strokeRoundedArrowUp01,
                  size: 18,
                  color: textColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
                Text(
                  totalLabel,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontFeatures: SacMoney.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CategoryTotalRow(
                item: item,
                isIncome: isIncome,
                groupTotal: groupTotal,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Row ────────────────────────────────────────────────────────────────────────

/// Fila de una categoría: nombre, total firmado, barra proporcional al total
/// del grupo y cantidad de movimientos.
class CategoryTotalRow extends StatelessWidget {
  const CategoryTotalRow({
    super.key,
    required this.item,
    required this.isIncome,
    required this.groupTotal,
  });

  final CategoryTotal item;
  final bool isIncome;
  final double groupTotal;

  /// Proporción 0..1 de la categoría dentro de su grupo.
  double get share =>
      groupTotal <= 0 ? 0 : (item.total / groupTotal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final amount = SacMoney.format(
      isIncome ? item.total : -item.total,
      signed: true,
    );
    final count = 'finances.by_category.count'.plural(item.count);
    final percent = (share * 100).round();
    final shareLabel = 'finances.by_category.share'.tr(
      namedArgs: {'percent': percent.toString()},
    );

    return Semantics(
      container: true,
      label: '${item.name}, $amount, $count, $shareLabel',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amount,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w600,
                  color: isIncome
                      ? FinanceTokens.incomeText(context)
                      : FinanceTokens.expenseText(context),
                  fontFeatures: SacMoney.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SacTweenedBar(
            value: share,
            color: isIncome
                ? FinanceTokens.incomeFill(context)
                : FinanceTokens.expenseFill(context),
            backgroundColor: c.surfaceVariant,
            minHeight: 6,
            borderRadius: AppTheme.radiusXS,
          ),
          const SizedBox(height: 4),
          Text(
            '$count · $shareLabel',
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading ────────────────────────────────────────────────────────────────────

class _BreakdownSkeleton extends StatelessWidget {
  const _BreakdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SacShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SacSkeletonBox(height: 16, width: 120),
            SizedBox(height: 14),
            SacSkeletonBox(height: 12),
            SizedBox(height: 8),
            SacSkeletonBox(height: 6),
            SizedBox(height: 16),
            SacSkeletonBox(height: 12),
            SizedBox(height: 8),
            SacSkeletonBox(height: 6),
          ],
        ),
      ),
    );
  }
}
