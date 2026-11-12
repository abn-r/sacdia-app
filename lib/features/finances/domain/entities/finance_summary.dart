import 'package:equatable/equatable.dart';

/// Resumen financiero agregado del club.
///
/// Devuelto por [GET /clubs/:clubId/finances/summary].
///
/// Significado de los montos (contrato vigente del backend):
/// - [totalIncome] / [totalExpense] / [net]: SOLO el período pedido (el mes
///   cuando se envían año y mes).
/// - [totalBalance]: saldo acumulado de toda la historia hasta el fin del
///   período; no se reinicia con el año eclesiástico.
/// - [yearIncome] / [yearExpense]: acumulado del año eclesiástico hasta el mes.
/// - [periodClosed]: si el mes pedido está cerrado; `null` sin mes.
class FinanceSummary extends Equatable {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;

  /// Ingresos menos egresos del período.
  final double net;

  /// Ingresos del año eclesiástico hasta el mes pedido.
  final double yearIncome;

  /// Egresos del año eclesiástico hasta el mes pedido.
  final double yearExpense;

  /// Cantidad de movimientos del período.
  final int movementCount;

  /// `true` si el mes está cerrado, `false` si está abierto, `null` si el
  /// resumen no es de un mes concreto.
  final bool? periodClosed;

  const FinanceSummary({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    this.net = 0,
    this.yearIncome = 0,
    this.yearExpense = 0,
    this.movementCount = 0,
    this.periodClosed,
  });

  @override
  List<Object?> get props => [
        totalBalance,
        totalIncome,
        totalExpense,
        net,
        yearIncome,
        yearExpense,
        movementCount,
        periodClosed,
      ];
}
