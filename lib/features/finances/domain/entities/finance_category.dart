import 'package:equatable/equatable.dart';

import 'transaction.dart';

/// Categoría de un movimiento financiero.
class FinanceCategory extends Equatable {
  final int id;
  final String name;
  final String? description;

  /// Índice de ícono almacenado en la BD.
  final int iconIndex;

  /// Tipo de categoría según el backend: 0 = ingreso, 1 = egreso.
  final int typeCode;

  const FinanceCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconIndex = 0,
    this.typeCode = 0,
  });

  /// Devuelve true si la categoría aplica a [TransactionType.income].
  bool get appliesToIncome => typeCode == 0;

  /// Devuelve true si la categoría aplica a [TransactionType.expense].
  bool get appliesToExpense => typeCode != 0;

  @override
  List<Object?> get props => [id, name, description, iconIndex, typeCode];
}
