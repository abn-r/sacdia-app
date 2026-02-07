import 'package:equatable/equatable.dart';
import '../../domain/entities/user_honor.dart';

/// Modelo de especialidad de usuario para la capa de datos
class UserHonorModel extends Equatable {
  final int id;
  final int honorId;
  final String userId;
  final String status;
  final DateTime? startDate;
  final DateTime? completionDate;

  const UserHonorModel({
    required this.id,
    required this.honorId,
    required this.userId,
    required this.status,
    this.startDate,
    this.completionDate,
  });

  /// Crea una instancia desde JSON
  factory UserHonorModel.fromJson(Map<String, dynamic> json) {
    return UserHonorModel(
      id: json['id'] as int,
      honorId: json['honor_id'] as int,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      completionDate: json['completion_date'] != null
          ? DateTime.parse(json['completion_date'] as String)
          : null,
    );
  }

  /// Convierte la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'honor_id': honorId,
      'user_id': userId,
      'status': status,
      'start_date': startDate?.toIso8601String(),
      'completion_date': completionDate?.toIso8601String(),
    };
  }

  /// Convierte el modelo a entidad de dominio
  UserHonor toEntity() {
    return UserHonor(
      id: id,
      honorId: honorId,
      userId: userId,
      status: status,
      startDate: startDate,
      completionDate: completionDate,
    );
  }

  /// Crea una copia con campos actualizados
  UserHonorModel copyWith({
    int? id,
    int? honorId,
    String? userId,
    String? status,
    DateTime? startDate,
    DateTime? completionDate,
  }) {
    return UserHonorModel(
      id: id ?? this.id,
      honorId: honorId ?? this.honorId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      completionDate: completionDate ?? this.completionDate,
    );
  }

  @override
  List<Object?> get props => [id, honorId, userId, status, startDate, completionDate];
}
