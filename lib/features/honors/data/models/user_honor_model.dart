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
    // PK is 'user_honor_id'; 'id' as fallback
    final id = (json['user_honor_id'] ?? json['id']) as int;

    // Status derived from boolean fields: validate=true → completed, else in_progress
    final validate = json['validate'] as bool? ?? false;
    final status = json['status'] as String? ??
        (validate ? 'completed' : 'in_progress');

    // Date field: 'date' is the honor date, 'created_at' as fallback
    final dateRaw = json['date'] as String? ?? json['created_at'] as String?;
    final startDate = dateRaw != null ? DateTime.tryParse(dateRaw) : null;

    final completionRaw = json['completion_date'] as String?;

    return UserHonorModel(
      id: id,
      honorId: json['honor_id'] as int,
      userId: json['user_id'] as String,
      status: status,
      startDate: startDate,
      completionDate: completionRaw != null
          ? DateTime.tryParse(completionRaw)
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
