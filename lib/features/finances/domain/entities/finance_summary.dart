import 'package:equatable/equatable.dart';

/// Resumen financiero agregado del club.
///
/// Devuelto por [GET /clubs/:clubId/finances/summary].
class FinanceSummary extends Equatable {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;

  /// Resumen por mes: lista de entradas [{year, month, income, expense}].
  final List<MonthlyBar> monthlyBars;

  const FinanceSummary({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.monthlyBars,
  });

  @override
  List<Object?> get props =>
      [totalBalance, totalIncome, totalExpense, monthlyBars];
}

/// Datos de un mes para la barra del gráfico.
class MonthlyBar extends Equatable {
  final int year;
  final int month;
  final double income;
  final double expense;

  const MonthlyBar({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  @override
  List<Object?> get props => [year, month, income, expense];
}
