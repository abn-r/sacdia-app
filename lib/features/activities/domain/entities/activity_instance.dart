import 'package:equatable/equatable.dart';

/// Representa una instancia de una actividad en una sección de club específica.
///
/// Las actividades conjuntas (is_joint = true) tienen múltiples instancias,
/// una por cada sección participante.
class ActivityInstance extends Equatable {
  final int clubSectionId;
  final int clubTypeId;
  final String? clubTypeName;

  const ActivityInstance({
    required this.clubSectionId,
    required this.clubTypeId,
    this.clubTypeName,
  });

  @override
  List<Object?> get props => [clubSectionId, clubTypeId, clubTypeName];
}
