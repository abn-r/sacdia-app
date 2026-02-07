import 'package:equatable/equatable.dart';

/// Entidad de asistencia a actividad del dominio
class Attendance extends Equatable {
  final int id;
  final int activityId;
  final String userId;
  final bool attended;
  final DateTime timestamp;

  const Attendance({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.attended,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, activityId, userId, attended, timestamp];
}
