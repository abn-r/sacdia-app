import 'package:equatable/equatable.dart';

/// Estado de una inscripción anual.
enum EnrollmentStatus { active, inactive, pending }

/// Par de día + hora de reunión.
class MeetingSchedule extends Equatable {
  final String day;
  final String time;

  const MeetingSchedule({
    required this.day,
    required this.time,
  });

  Map<String, dynamic> toJson() => {'day': day, 'time': time};

  factory MeetingSchedule.fromJson(Map<String, dynamic> json) {
    return MeetingSchedule(
      day: json['day']?.toString() ?? '',
      time: json['time']?.toString() ?? '09:00',
    );
  }

  @override
  List<Object?> get props => [day, time];
}

/// Entidad de dominio para la inscripción anual de un miembro al club.
class Enrollment extends Equatable {
  final int id;
  final String userId;
  final int clubSectionId;
  final int year;
  final String? address;
  final double? lat;
  final double? long;
  final List<String> meetingDays;

  /// Días de reunión con su horario asociado.
  final List<MeetingSchedule> meetingSchedule;
  final EnrollmentStatus status;
  final DateTime? createdAt;

  // Nuevos campos (backend pendiente)
  final int? soulsTarget;
  final bool? fee;
  final double? feeAmount;
  final String? directorId;
  final List<String> deputyDirectorIds;
  final String? secretaryId;
  final String? treasurerId;
  final String? secretaryTreasurerId;

  const Enrollment({
    required this.id,
    required this.userId,
    required this.clubSectionId,
    required this.year,
    this.address,
    this.lat,
    this.long,
    required this.meetingDays,
    this.meetingSchedule = const [],
    required this.status,
    this.createdAt,
    this.soulsTarget,
    this.fee,
    this.feeAmount,
    this.directorId,
    this.deputyDirectorIds = const [],
    this.secretaryId,
    this.treasurerId,
    this.secretaryTreasurerId,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        clubSectionId,
        year,
        address,
        lat,
        long,
        meetingDays,
        meetingSchedule,
        status,
        createdAt,
        soulsTarget,
        fee,
        feeAmount,
        directorId,
        deputyDirectorIds,
        secretaryId,
        treasurerId,
        secretaryTreasurerId,
      ];
}
