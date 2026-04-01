import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/finance_summary.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';
import 'period_selector.dart';

/// Area line chart that overlays income (green) and expense (red) lines.
///
/// Reads [selectedPeriodProvider] for the active time range and sources data
/// from [financeMonthProvider] (1M — daily aggregation) or
/// [financeSummaryProvider] (3M / 6M / 1A / Todo — monthly bars).
class FinanceLineChart extends ConsumerWidget {
  const FinanceLineChart({super.key});

  // ── Brand colors ────────────────────────────────────────────────────────────
  static const _incomeColor = Color(0xFF4FBF9F);
  static const _expenseColor = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final period = ref.watch(selectedPeriodProvider);

    final chartSurface =
        isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFBFC);
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final tooltipBg =
        isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: chartSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumen del Mes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                children: [
                  _LegendDot(color: _incomeColor, label: 'Ingresos'),
                  const SizedBox(width: 12),
                  _LegendDot(color: _expenseColor, label: 'Egresos'),
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
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const _EmptyState(),
      data: (month) {
        if (month == null || month.transactions.isEmpty) {
          return const _EmptyState();
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
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;

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
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const _EmptyState(),
      data: (summary) {
        if (summary == null || summary.monthlyBars.isEmpty) {
          return const _EmptyState();
        }

        final bars = _filterBars(summary.monthlyBars, period);
        if (bars.isEmpty) return const _EmptyState();

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
    final sorted = [...bars]
      ..sort((a, b) {
        final cmp = a.year.compareTo(b.year);
        return cmp != 0 ? cmp : a.month.compareTo(b.month);
      });

    switch (period) {
      case '3M':
        return sorted.length > 3
            ? sorted.sublist(sorted.length - 3)
            : sorted;
      case '6M':
        return sorted.length > 6
            ? sorted.sublist(sorted.length - 6)
            : sorted;
      case '1A':
        return sorted.length > 12
            ? sorted.sublist(sorted.length - 12)
            : sorted;
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

  static const _incomeColor = FinanceLineChart._incomeColor;
  static const _expenseColor = FinanceLineChart._expenseColor;

  @override
  Widget build(BuildContext context) {
    final allValues = [
      ...incomeSpots.map((s) => s.y),
      ...expenseSpots.map((s) => s.y),
    ];
    final maxValue =
        allValues.isEmpty ? 1.0 : allValues.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    return SizedBox(
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
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    _xLabel(value, context, isDark),
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
                  '\$${_formatAmount(spot.y)}',
                  TextStyle(
                    color:
                        isIncome ? _incomeColor : _expenseColor,
                    fontSize: 11,
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
              color: _incomeColor,
              fillOpacity: 0.30,
            ),
            _buildLine(
              spots: expenseSpots,
              color: _expenseColor,
              fillOpacity: 0.25,
            ),
          ],
        ),
      ),
    );
  }

  // ── Line bar builder ───────────────────────────────────────────────────────

  LineChartBarData _buildLine({
    required List<FlSpot> spots,
    required Color color,
    required double fillOpacity,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.5,
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
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        _formatYValue(value),
        style: TextStyle(
          fontSize: 9,
          color: labelColor,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  String _formatYValue(double v) {
    if (v == 0) return '\$0';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _formatAmount(double v) {
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}k';
    }
    return v.toStringAsFixed(0);
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

  Widget _xLabel(double value, BuildContext context, bool isDark) {
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    final label = _buildXLabel(value);
    if (label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: labelColor,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  String _buildXLabel(double value) {
    const monthNames = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];

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
        return monthNames[bar.month - 1];

      case '6M':
        final idx = value.round();
        if (idx < 0 || idx >= monthlyBars.length) return '';
        final bar = monthlyBars[idx];
        return monthNames[bar.month - 1];

      case '1A':
        final idx = value.round();
        if (idx < 0 || idx >= monthlyBars.length) return '';
        // Only show every other label to avoid crowding.
        if (idx % 2 != 0) return '';
        final bar = monthlyBars[idx];
        return monthNames[bar.month - 1];

      case 'Todo':
      default:
        final idx = value.round();
        if (idx < 0 || idx >= monthlyBars.length) return '';
        final bar = monthlyBars[idx];
        // Show month + last two digits of year.
        final yr = bar.year % 100;
        return '${monthNames[bar.month - 1]} ${yr.toString().padLeft(2, '0')}';
    }
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          'Sin datos para el período',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.sac.textTertiary,
              ),
        ),
      ),
    );
  }
}

// ── Legend dot ─────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.sac.textSecondary,
          ),
        ),
      ],
    );
  }
}
