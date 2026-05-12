import 'package:equatable/equatable.dart';

/// Entidad de dominio que representa un club visible para un coordinador.
///
/// Encapsula la información mínima necesaria para la lista de clubes en
/// el panel de coordinación. Los coordinadores ven todos los clubes de su
/// campo local sin importar la sección (Conquistadores, Aventureros, GM).
class CoordinatorClub extends Equatable {
  /// ID numérico del club (club_id).
  final int id;

  /// Nombre del club.
  final String name;

  /// ID del campo local al que pertenece el club.
  final int localFieldId;

  const CoordinatorClub({
    required this.id,
    required this.name,
    required this.localFieldId,
  });

  @override
  List<Object?> get props => [id, name, localFieldId];
}
