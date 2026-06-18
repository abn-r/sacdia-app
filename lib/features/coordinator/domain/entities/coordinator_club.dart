import 'package:equatable/equatable.dart';
import 'coordinator_scope.dart';

/// Entidad de dominio que representa un club visible para un coordinador.
///
/// Encapsula la información mínima necesaria para la lista de clubes en
/// el panel de coordinación. El acceso real se deriva de las secciones
/// asignadas al coordinador.
class CoordinatorClub extends Equatable {
  /// ID numérico del club (club_id).
  final int id;

  /// Nombre del club.
  final String name;

  /// ID del campo local al que pertenece el club.
  final int localFieldId;

  /// Nombre del campo local, cuando el backend lo expone.
  final String? localFieldName;

  /// Nombre del distrito, cuando el backend lo expone.
  final String? districtName;

  /// Secciones específicas que el coordinador puede gestionar en este club.
  final List<CoordinatorSectionScope> sections;

  const CoordinatorClub({
    required this.id,
    required this.name,
    required this.localFieldId,
    this.localFieldName,
    this.districtName,
    this.sections = const [],
  });

  int get sectionCount => sections.length;

  String get sectionSummary {
    final labels = sections.map((section) => section.displayName).toSet();
    return labels.join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        name,
        localFieldId,
        localFieldName,
        districtName,
        sections,
      ];
}
