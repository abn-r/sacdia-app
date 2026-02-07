import 'package:equatable/equatable.dart';

/// Entidad de especialidad de usuario del dominio
class UserHonor extends Equatable {
  final int id;
  final int honorId;
  final String userId;
  final String status; // 'in_progress', 'completed', 'pending'
  final DateTime? startDate;
  final DateTime? completionDate;

  const UserHonor({
    required this.id,
    required this.honorId,
    required this.userId,
    required this.status,
    this.startDate,
    this.completionDate,
  });

  @override
  List<Object?> get props => [id, honorId, userId, status, startDate, completionDate];
}
