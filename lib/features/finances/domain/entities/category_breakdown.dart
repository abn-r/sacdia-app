import 'package:equatable/equatable.dart';

/// Total de una categoría en el período consultado.
class CategoryTotal extends Equatable {
  final int categoryId;
  final String name;
  final double total;
  final int count;

  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.total,
    required this.count,
  });

  @override
  List<Object?> get props => [categoryId, name, total, count];
}

/// Ingresos y egresos agrupados por categoría de un período.
///
/// Devuelto por `GET /clubs/:clubId/finances/by-category`. Cada lista llega
/// ordenada de mayor a menor total y con los nombres ya traducidos.
class CategoryBreakdown extends Equatable {
  final String period;
  final List<CategoryTotal> income;
  final List<CategoryTotal> expenses;
  final double totalIncome;
  final double totalExpenses;

  const CategoryBreakdown({
    required this.period,
    required this.income,
    required this.expenses,
    required this.totalIncome,
    required this.totalExpenses,
  });

  bool get isEmpty => income.isEmpty && expenses.isEmpty;

  @override
  List<Object?> get props =>
      [period, income, expenses, totalIncome, totalExpenses];
}
