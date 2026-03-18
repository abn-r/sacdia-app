import 'package:equatable/equatable.dart';

import 'transaction.dart';

/// Resumen financiero de un período mensual del club.
///
/// Contiene los movimientos del mes y las estadísticas calculadas.
class FinanceMonth extends Equatable {
  final int year;
  final int month; // 1–12
  final bool isOpen;
  final double totalBalance; // saldo acumulado total del club
  final double totalIncome; // ingresos del mes
  final double totalExpense; // egresos del mes
  final List<FinanceTransaction> transactions;

  const FinanceMonth({
    required this.year,
    required this.month,
    required this.isOpen,
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactions,
  });

  double get netMonth => totalIncome - totalExpense;

  @override
  List<Object?> get props => [
        year,
        month,
        isOpen,
        totalBalance,
        totalIncome,
        totalExpense,
        transactions,
      ];
}
