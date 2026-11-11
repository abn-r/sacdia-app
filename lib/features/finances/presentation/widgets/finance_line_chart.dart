import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/finance_summary.dart';
import '../providers/finances_providers.dart';
import '../theme/finance_tokens.dart';
import 'period_selector.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Area line chart that overlays income (green) and expense (red) lines.
///
/// Reads [selectedPeriodProvider] for the active time range and sources data
/// from [financeMonthProvider] (1M — daily aggregation) or
/// [financeSummaryProvider] (3M / 6M / 1A / Todo — monthly bars).
class FinanceLineChart extends ConsumerWidget {
  const FinanceLineChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final period = ref.watch(selectedPeriodProvider);
    final incomeColor = FinanceTokens.incomeFill(context);
    final expenseColor = FinanceTokens.expenseFill(context);

    final chartSurface = context.sac.canvas;
    final gridColor = FinanceTokens.chartGrid(context);
    final tooltipBg = context.sac.paper;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: chartSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'finances.widgets.chart_title'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                children: [
                  _LegendDot(
                      color: incomeColor,
                      label: 'finances.widgets.chart_income'.tr()),
                  const SizedBox(width: 12),
                  _LegendDot(
                      color: expenseColor,
                      square: true,
                      label: 'finances.widgets.chart_expense'.tr()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Chart body ──────────────────────────────────────────────────────
          if (period == '1M')
            _MonthlyChart(
              isDark: isDark,
              gridColor: gridColor,
              tooltipBg: tooltipBg,
            )
          else
            _SummaryChart(
              period: period,
              isDark: isDark,
              gridColor: gridColor,
              tooltipBg: tooltipBg,
            ),

          const SizedBox(height: 12),

          // ── Period selector ─────────────────────────────────────────────────
          PeriodSelector(
            selected: period,
            onChanged: (p) =>
                ref.read(selectedPeriodProvider.notifier).state = p,
          ),
        ],
      ),
    );
  }
}

// ── 1M chart — aggregates transactions by day ──────────────────────────────

class _MonthlyChart extends ConsumerWidget {
  final bool isDark;
  final Color gridColor;
  final Color tooltipBg;

  const _MonthlyChart({
    required this.isDark,
    required this.gridColor,
    required this.tooltipBg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMonth = ref.watch(financeMonthProvider);

    return asyncMonth.when(
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: SacLoading()),
      ),
      error: (e, _) => _ChartError(
        message: userErrorMessage(e),
        onRetry: () => invalidateFinanceData(ref.invalidate),
      ),
      data: (month) {
        if (month == null || month.transactions.isEmpty) {
          return const _ChartEmpty();
        }
        final data = _aggregateByDay(month);
        return _ChartView(
          incomeSpots: data.$1,
          expenseSpots: data.$2,
          period: '1M',
          isDark: isDark,
          gridColor: gridColor,
          tooltipBg: tooltipBg,
          month: month,
          monthlyBars: const [],
        );
      },
    );
  }

  /// Aggregates [FinanceMonth.transactions] into daily income/expense totals.
  ///
  /// Returns a record of (incomeSpots, expenseSpots) where x is the day number.
  (List<FlSpot>, List<FlSpot>) _aggregateByDay(FinanceMonth month) {
    final incomeMap = <int, double>{};
    final expenseMap = <int, double>{};

    for (final tx in month.transactions) {
      final day = tx.date.day;
      if (tx.type.isIncome) {
        incomeMap[day] = (incomeMap[day] ?? 0) + tx.amount;
      } else {
        expenseMap[day] = (expenseMap[day] ?? 0) + tx.amount;
      }
    }

    // Determine the number of days to plot (days in the month).
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (int d = 1; d <= daysInMonth; d++) {
      incomeSpots.add(FlSpot(d.toDouble(), incomeMap[d] ?? 0));
      expenseSpots.add(FlSpot(d.toDouble(), expenseMap[d] ?? 0));
    }

    return (incomeSpots, expenseSpots);
  }
}

// ── Multi-period chart — uses financeSummaryProvider ──────────────────────

class _SummaryChart extends ConsumerWidget {
  final String period;
  final bool isDark;
  final Color gridColor;
  final Color tooltipBg;

  const _SummaryChart({
    required this.period,
    required this.isDark,
    required this.gridColor,
    required this.tooltipBg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSummary = ref.watch(financeSummaryProvider);

    return asyncSummary.when(
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: SacLoading()),
      ),
      error: (e, _) => _ChartError(
        message: userErrorMessage(e),
        onRetry: () => invalidateFinanceData(ref.invalidate),
      ),
      data: (summary) {
        if (summary == null || summary.monthlyBars.isEmpty) {
          return const _ChartEmpty();
        }

        final bars = _filterBars(summary.monthlyBars, period);
        if (bars.isEmpty) return const _ChartEmpty();

        final incomeSpots = <FlSpot>[];
        final expenseSpots = <FlSpot>[];

        for (int i = 0; i < bars.length; i++) {
          incomeSpots.add(FlSpot(i.toDouble(), bars[i].income));
          expenseSpots.add(FlSpot(i.toDouble(), bars[i].expense));
        }

        return _ChartView(
          incomeSpots: incomeSpots,
          expenseSpots: expenseSpots,
          period: period,
          isDark: isDark,
          gridColor: gridColor,
          tooltipBg: tooltipBg,
          month: null,
          monthlyBars: bars,
        );
      },
    );
  }

  List<MonthlyBar> _filterBars(List<MonthlyBar> bars, String period) {
    final sorted = [...bars]..sort((a, b) {
        final cmp = a.year.compareTo(b.year);
        return cmp != 0 ? cmp : a.month.compareTo(b.month);
      });

    switch (period) {
      case '3M':
        return sorted.length > 3 ? sorted.sublist(sorted.length - 3) : sorted;
      case '6M':
        return sorted.length > 6 ? sorted.sublist(sorted.length - 6) : sorted;
      case '1A':
        return sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;
      case 'Todo':
      default:
        return sorted;
    }
  }
}

// ── Shared chart view ──────────────────────────────────────────────────────

class _ChartView extends StatelessWidget {
  final List<FlSpot> incomeSpots;
  final List<FlSpot> expenseSpots;
  final String period;
  final bool isDark;
  final Color gridColor;
  final Color tooltipBg;

  /// Only non-null when period == '1M'.
  final FinanceMonth? month;

  /// Used for x-axis labels in multi-period modes.
  final List<MonthlyBar> monthlyBars;

  const _ChartView({
    required this.incomeSpots,
    required this.expenseSpots,
    required this.period,
    required this.isDark,
    required this.gridColor,
    required this.tooltipBg,
    required this.month,
    required this.monthlyBars,
  });

  @override
  Widget build(BuildContext context) {
    final incomeColor = FinanceTokens.incomeFill(context);
    final expenseColor = FinanceTokens.expenseFill(context);
    final incomeTextColor = FinanceTokens.incomeText(context);
    final expenseTextColor = FinanceTokens.expenseText(context);
    final allValues = [
      ...incomeSpots.map((s) => s.y),
      ...expenseSpots.map((s) => s.y),
    ];
    final maxValue =
        allValues.isEmpty ? 1.0 : allValues.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;
    final locale = context.locale.toString();
    final totalIncome = incomeSpots.fold<double>(0, (sum, s) => sum + s.y);
    final totalExpense = expenseSpots.fold<double>(0, (sum, s) => sum + s.y);

    // Text alternative of the plot: the lines are not readable by a screen
    // reader, so the totals of the shown period are announced instead.
    return Semantics(
      container: true,
      label: 'finances.widgets.chart_a11y_summary'.tr(
        namedArgs: {
          'income': SacMoney.format(totalIncome),
          'expense': SacMoney.format(totalExpense),
        },
      ),
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMaxY,
                clipData: const FlClipData.all(),

                // ── Grid ──────────────────────────────────────────────────────────
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                ),

                // ── Borders ───────────────────────────────────────────────────────
                borderData: FlBorderData(show: false),

                // ── Axes ──────────────────────────────────────────────────────────
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: chartMaxY / 4,
                      getTitlesWidget: (value, meta) =>
                          _yLabel(value, context, isDark),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: _xInterval,
                      getTitlesWidget: (value, meta) =>
                          _xLabel(value, context, isDark, locale),
                    ),
                  ),
                ),

                // ── Touch ─────────────────────────────────────────────────────────
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => tooltipBg,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final isIncome = spot.barIndex == 0;
                      return LineTooltipItem(
                        SacMoney.compact(spot.y),
                        TextStyle(
                          color: isIncome ? incomeTextColor : expenseTextColor,
                          fontSize: SacFontSize.labelSmall,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                  handleBuiltInTouches: true,
                ),

                // ── Lines ─────────────────────────────────────────────────────────
                lineBarsData: [
                  _buildLine(
                    spots: incomeSpots,
                    color: incomeColor,
                    fillOpacity: 0.30,
                  ),
                  _buildLine(
                    spots: expenseSpots,
                    color: expenseColor,
                    fillOpacity: 0.25,
                    dashed: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Line bar builder ───────────────────────────────────────────────────────

  LineChartBarData _buildLine({
    required List<FlSpot> spots,
    required Color color,
    required double fillOpacity,
    bool dashed = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.5,
      dashArray: dashed ? const [6, 4] : null,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: fillOpacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  // ── Y-axis label ──────────────────────────────────────────────────────────

  Widget _yLabel(double value, BuildContext context, bool isDark) {
    final labelColor = context.sac.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        SacMoney.compact(value),
        style: TextStyle(
          fontSize: SacFontSize.micro,
          color: labelColor,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  // ── X-axis label ──────────────────────────────────────────────────────────

  double get _xInterval {
    switch (period) {
      case '1M':
        return 7;
      case '3M':
        // bars count ≤ 3, show all
        return 1;
      case '6M':
        return 1;
      case '1A':
        return 2;
      case 'Todo':
      default:
        final count = monthlyBars.length;
        return count <= 6 ? 1 : (count / 6).ceilToDouble();
    }
  }

  Widget _xLabel(
    double value,
    BuildContext context,
    bool isDark,
    String locale,
  ) {
    final labelColor = context.sac.textSecondary;

    final label = _buildXLabel(value, locale);
    if (label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: SacFontSize.micro,
          color: labelColor,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  /// Short month name in the app language ("Ene", "Jan", "Janv."...).
  String _monthName(int month, String locale) {
    final name = DateFormat.MMM(locale).format(DateTime(2000, month));
    return name[0].toUpperCase() + name.substring(1);
  }

  String _buildXLabel(double value, String locale) {
    switch (period) {
      case '1M':
        // x = day number. Show labels at 1, 7, 14, 21, 28.
        final day = value.round();
        if (day == 1 || day == 7 || day == 14 || day == 21 || day == 28) {
          return '$day';
        }
        return '';

      case '3M':
        // x = index into bars (0-based). Show month abbreviation.
        final idx = value.round();
        if (idx < 0 || idx >= monthlyBars.length) return '';
        final bar = monthlyBars[idx];
        return _monthName(bar.month, locale);

      case '6M':
        final idx = value.round();
        if (idx < 0 || idx >= monthlyBars.length) return '';
        final bar = monthlyBars[idx];
        return _monthName(bar.month, locale);

      case '1A':
        final idx = value.round();
        if (idx < 0 || idx >= monthlyBars.length) return '';
        // Only show every other label to avoid crowding.
        if (idx % 2 != 0) return '';
        final bar = monthlyBars[idx];
        return _monthName(bar.month, locale);

      case 'Todo':
      default:
        final idx = value.round();
        if (idx < 0 || idx >= monthlyBars.length) return '';
        final bar = monthlyBars[idx];
        // Show month + last two digits of year.
        final yr = bar.year % 100;
        return '${_monthName(bar.month, locale)} ${yr.toString().padLeft(2, '0')}';
    }
  }
}

// ── Empty / error (inline, fixed chart height) ─────────────────────────────

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: SacEmptyState.inline(
          title: 'finances.widgets.chart_no_data'.tr(),
        ),
      ),
    );
  }
}

class _ChartError extends StatelessWidget {
  const _ChartError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: SacErrorState.inline(message: message, onRetry: onRetry),
      ),
    );
  }
}

// ── Legend dot ─────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool square;

  const _LegendDot({
    required this.color,
    required this.label,
    this.square = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: square ? BoxShape.rectangle : BoxShape.circle,
            borderRadius:
                square ? BorderRadius.circular(AppTheme.radiusHairline) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: SacFontSize.labelSmall,
            fontWeight: FontWeight.w500,
            color: context.sac.textSecondary,
          ),
        ),
      ],
    );
  }
}
