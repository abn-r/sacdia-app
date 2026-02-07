import 'package:equatable/equatable.dart';
import '../../domain/entities/attendance.dart';

/// Modelo de asistencia para la capa de datos
class AttendanceModel extends Equatable {
  final int id;
  final int activityId;
  final String userId;
  final bool attended;
  final DateTime timestamp;

  const AttendanceModel({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.attended,
    required this.timestamp,
  });

  /// Crea una instancia desde JSON
  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as int,
      activityId: json['activity_id'] as int,
      userId: json['user_id'] as String,
      attended: json['attended'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activity_id': activityId,
      'user_id': userId,
      'attended': attended,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  Attendance toEntity() {
    return Attendance(
      id: id,
      activityId: activityId,
      userId: userId,
      attended: attended,
      timestamp: timestamp,
    );
  }

  /// Crea una copia con campos actualizados
  AttendanceModel copyWith({
    int? id,
    int? activityId,
    String? userId,
    bool? attended,
    DateTime? timestamp,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      userId: userId ?? this.userId,
      attended: attended ?? this.attended,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [id, activityId, userId, attended, timestamp];
}
