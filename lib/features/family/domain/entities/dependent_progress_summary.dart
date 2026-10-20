import 'package:equatable/equatable.dart';

/// Progreso de una clase en el resumen del tutor.
class ClassProgressSummary extends Equatable {
  final int? classId;
  final String name;
  final int progressPercent;
  final int sectionsCompleted;
  final int sectionsTotal;

  const ClassProgressSummary({
    required this.name,
    required this.progressPercent,
    required this.sectionsCompleted,
    required this.sectionsTotal,
    this.classId,
  });

  @override
  List<Object?> get props => [
        classId,
        name,
        progressPercent,
        sectionsCompleted,
        sectionsTotal,
      ];
}

/// Asistencia del año eclesiástico vigente.
class AttendanceSummary extends Equatable {
  final DateTime? from;
  final DateTime? to;
  final int activitiesTotal;
  final int activitiesAttended;

  const AttendanceSummary({
    this.from,
    this.to,
    this.activitiesTotal = 0,
    this.activitiesAttended = 0,
  });

  /// 0 a 100; 0 si no hubo actividades.
  int get percent => activitiesTotal <= 0
      ? 0
      : ((activitiesAttended * 100) / activitiesTotal).round().clamp(0, 100);

  @override
  List<Object?> get props => [from, to, activitiesTotal, activitiesAttended];
}

/// `GET .../dependents/:id/summary` (FP3-26): lo ÚNICO que el tutor ve de un
/// menor con acceso propio — progreso y asistencia. Sin salud, evidencias,
/// notas, contacto, ubicación ni mensajes: el parseo solo toma las llaves de
/// esta lista y descarta cualquier otra.
class DependentProgressSummary extends Equatable {
  final String userId;
  final String? name;
  final int? age;
  final bool supervisedLogin;
  final List<ClassProgressSummary> classes;
  final int honorsCompleted;
  final int honorsInProgress;
  final AttendanceSummary attendance;
  final DateTime? generatedAt;

  const DependentProgressSummary({
    required this.userId,
    this.name,
    this.age,
    this.supervisedLogin = false,
    this.classes = const [],
    this.honorsCompleted = 0,
    this.honorsInProgress = 0,
    this.attendance = const AttendanceSummary(),
    this.generatedAt,
  });

  @override
  List<Object?> get props => [
        userId,
        name,
        age,
        supervisedLogin,
        classes,
        honorsCompleted,
        honorsInProgress,
        attendance,
        generatedAt,
      ];
}
