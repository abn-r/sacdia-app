import 'package:equatable/equatable.dart';

/// Estado de una inscripción anual.
enum EnrollmentStatus { active, inactive, pending }

/// Entidad de dominio para la inscripción anual de un miembro al club.
class Enrollment extends Equatable {
  final int id;
  final String userId;
  final int clubSectionId;
  final int year;
  final String? address;
  final List<String> meetingDays;
  final EnrollmentStatus status;
  final DateTime? createdAt;

  const Enrollment({
    required this.id,
    required this.userId,
    required this.clubSectionId,
    required this.year,
    this.address,
    required this.meetingDays,
    required this.status,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        clubSectionId,
        year,
        address,
        meetingDays,
        status,
        createdAt,
      ];
}
