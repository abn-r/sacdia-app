import 'package:equatable/equatable.dart';

import 'transaction.dart';

/// Categoría de un movimiento financiero.
class FinanceCategory extends Equatable {
  final int id;
  final String name;
  final String? description;

  /// Índice de ícono almacenado en la BD (0 = genérico, ver [FinanceCategoryIcon]).
  final int iconIndex;

  /// Tipo de categoría: 1 = ingreso, 2 = egreso, 0 = ambos.
  final int typeCode;

  const FinanceCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconIndex = 0,
    this.typeCode = 0,
  });

  /// Devuelve true si la categoría aplica a [TransactionType.income].
  bool get appliesToIncome => typeCode == 0 || typeCode == 1;

  /// Devuelve true si la categoría aplica a [TransactionType.expense].
  bool get appliesToExpense => typeCode == 0 || typeCode == 2;

  @override
  List<Object?> get props => [id, name, description, iconIndex, typeCode];
}
