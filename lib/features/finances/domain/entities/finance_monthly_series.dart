import 'package:equatable/equatable.dart';

/// Un mes de la serie mensual del club.
class FinanceMonthlyPoint extends Equatable {
  final int year;
  final int month;
  final double income;
  final double expenses;

  /// Ingresos menos egresos del mes.
  final double net;

  /// Saldo acumulado de toda la historia al cierre del mes.
  final double balance;

  const FinanceMonthlyPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
    required this.net,
    required this.balance,
  });

  @override
  List<Object?> get props => [year, month, income, expenses, net, balance];
}

/// Serie mensual continua (incluye meses sin movimientos), de más antiguo a
/// más reciente.
///
/// Devuelta por `GET /clubs/:clubId/finances/monthly`.
class FinanceMonthlySeries extends Equatable {
  final List<FinanceMonthlyPoint> items;

  const FinanceMonthlySeries({required this.items});

  /// Sin meses, o ningún movimiento en todo el rango.
  bool get isEmpty => items.every((p) => p.income == 0 && p.expenses == 0);

  double get totalIncome => items.fold(0, (sum, p) => sum + p.income);

  double get totalExpenses => items.fold(0, (sum, p) => sum + p.expenses);

  @override
  List<Object?> get props => [items];
}
