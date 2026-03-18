import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/finance_summary.dart';

/// Gráfico de barras personalizado (sin dependencia externa) que muestra
/// ingresos vs egresos por mes para los últimos 6 meses.
///
/// Implementado con [CustomPainter] para máximo control visual.
class FinanceBarChart extends StatelessWidget {
  final List<MonthlyBar> bars;

  const FinanceBarChart({super.key, required this.bars});

  @override
  Widget build(BuildContext context) {
    // Tomar los últimos 6 meses.
    final displayBars = bars.length > 6 ? bars.sublist(bars.length - 6) : bars;

    if (displayBars.isEmpty) {
      return const _EmptyChart();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumen mensual',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                children: [
                  _Legend(color: AppColors.secondary, label: 'Ingresos'),
                  const SizedBox(width: 12),
                  _Legend(color: AppColors.error, label: 'Egresos'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 160,
            child: _BarChartPainterWidget(bars: displayBars),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BarChartPainterWidget extends StatelessWidget {
  final List<MonthlyBar> bars;

  const _BarChartPainterWidget({required this.bars});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _BarChartPainter(bars: bars, isDark: isDark),
      child: Container(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<MonthlyBar> bars;
  final bool isDark;

  _BarChartPainter({required this.bars, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    const barGroupWidth = 0.75; // fraction of slot for both bars
    const barSpacing = 0.04;
    const labelHeight = 20.0;
    const topPadding = 8.0;

    final chartHeight = size.height - labelHeight;
    final slotWidth = size.width / bars.length;
    final barWidth = (slotWidth * barGroupWidth - slotWidth * barSpacing) / 2;

    // Find max value for scaling.
    final maxVal = bars.fold<double>(
      1.0,
      (prev, b) => math.max(prev, math.max(b.income, b.expense)),
    );

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 1;

    // Draw 3 horizontal grid lines.
    for (int i = 1; i <= 3; i++) {
      final y = topPadding + (chartHeight - topPadding) * (1 - i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final slotLeft = slotWidth * i;
      final groupLeft = slotLeft + slotWidth * (1 - barGroupWidth) / 2;

      // Income bar
      _drawBar(
        canvas: canvas,
        left: groupLeft,
        barWidth: barWidth,
        value: bar.income,
        maxVal: maxVal,
        chartHeight: chartHeight,
        topPadding: topPadding,
        color: AppColors.secondary,
      );

      // Expense bar
      _drawBar(
        canvas: canvas,
        left: groupLeft + barWidth + slotWidth * barSpacing,
        barWidth: barWidth,
        value: bar.expense,
        maxVal: maxVal,
        chartHeight: chartHeight,
        topPadding: topPadding,
        color: AppColors.error,
      );

      // Month label
      final label = _shortMonth(bar.month);
      final tp = _makeTextPainter(
        label,
        isDark ? Colors.white54 : Colors.black45,
        11,
      );
      tp.layout(maxWidth: slotWidth);
      tp.paint(
        canvas,
        Offset(
          slotLeft + (slotWidth - tp.width) / 2,
          chartHeight + 6,
        ),
      );
    }
  }

  void _drawBar({
    required Canvas canvas,
    required double left,
    required double barWidth,
    required double value,
    required double maxVal,
    required double chartHeight,
    required double topPadding,
    required Color color,
  }) {
    if (value <= 0) return;

    final availableHeight = chartHeight - topPadding;
    final barHeight = (value / maxVal) * availableHeight;
    final top = topPadding + availableHeight - barHeight;

    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(left, top, barWidth, barHeight),
      topLeft: const Radius.circular(5),
      topRight: const Radius.circular(5),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.65)],
        ).createShader(rect.outerRect),
    );
  }

  TextPainter _makeTextPainter(String text, Color color, double size) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
  }

  String _shortMonth(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    if (month < 1 || month > 12) return '?';
    return months[month - 1];
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.bars != bars || old.isDark != isDark;
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Sin datos para mostrar el gráfico',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
