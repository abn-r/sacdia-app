import 'package:equatable/equatable.dart';

/// Programa (tipo de club) al que aplica un producto.
///
/// Los datos provienen de la tabla `club_types` del backend.
class MaterialProgram extends Equatable {
  final int id;
  final String label;

  const MaterialProgram({
    required this.id,
    required this.label,
  });

  @override
  List<Object?> get props => [id, label];
}
