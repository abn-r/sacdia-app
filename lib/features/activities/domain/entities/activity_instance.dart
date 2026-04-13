import 'package:equatable/equatable.dart';

/// Representa una instancia de una actividad en una sección de club específica.
///
/// Las actividades conjuntas (is_joint = true) tienen múltiples instancias,
/// una por cada sección participante.
///
/// Los campos provienen del método `attachInstances()` del backend, que transforma
/// la relación Prisma en objetos con `section_id`, `club_id` y `club_type_name`.
/// `clubTypeId` es opcional porque el backend no lo expone en este shape.
class ActivityInstance extends Equatable {
  final int clubSectionId;
  final int? clubTypeId;
  final int? clubId;
  final String? clubTypeName;

  const ActivityInstance({
    required this.clubSectionId,
    this.clubTypeId,
    this.clubId,
    this.clubTypeName,
  });

  @override
  List<Object?> get props => [clubSectionId, clubTypeId, clubId, clubTypeName];
}
