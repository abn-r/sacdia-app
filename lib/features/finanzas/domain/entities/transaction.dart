import 'package:equatable/equatable.dart';

import 'finance_category.dart';

/// Tipo de movimiento financiero.
enum TransactionType {
  income,
  expense;

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;
}

/// Representa un movimiento financiero individual del club.
class FinanceTransaction extends Equatable {
  final int id;
  final TransactionType type;

  /// Monto en centavos o unidad mínima de la moneda local.
  /// En la BD se almacena como Int.
  final double amount;
  final String description;
  final String? notes;
  final DateTime date;
  final int year;
  final int month;
  final FinanceCategory category;
  final String registeredByName;
  final DateTime registeredAt;
  final String? modifiedByName;
  final DateTime? modifiedAt;

  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.notes,
    required this.date,
    required this.year,
    required this.month,
    required this.category,
    required this.registeredByName,
    required this.registeredAt,
    this.modifiedByName,
    this.modifiedAt,
  });

  @override
  List<Object?> get props => [
        id,
        type,
        amount,
        description,
        notes,
        date,
        year,
        month,
        category,
        registeredByName,
        registeredAt,
        modifiedByName,
        modifiedAt,
      ];
}
