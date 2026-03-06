import 'package:equatable/equatable.dart';

/// Categoría de ítem de inventario (ej. Uniformes, Equipos, Materiales).
class InventoryCategory extends Equatable {
  final int id;
  final String name;

  const InventoryCategory({
    required this.id,
    required this.name,
  });

  @override
  List<Object?> get props => [id, name];
}
