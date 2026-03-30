import 'dart:convert';

import '../../domain/entities/enrollment.dart';

/// Modelo de datos para una inscripción anual.
///
/// Mapea la respuesta de:
///   POST /clubs/:clubId/sections/:sectionId/enrollments
///   GET  /clubs/:clubId/sections/:sectionId/enrollments/current
class EnrollmentModel extends Enrollment {
  const EnrollmentModel({
    required super.id,
    required super.userId,
    required super.clubSectionId,
    required super.year,
    super.address,
    super.lat,
    super.long,
    required super.meetingDays,
    super.meetingSchedule = const [],
    required super.status,
    super.createdAt,
    super.soulsTarget,
    super.fee,
    super.feeAmount,
    super.directorId,
    super.deputyDirectorIds = const [],
    super.secretaryId,
    super.treasurerId,
    super.secretaryTreasurerId,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['enrollment_id'] ?? json['club_enrollment_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    final rawSectionId = json['club_section_id'] ?? json['section_id'];
    final sectionId =
        rawSectionId is int ? rawSectionId : int.tryParse(rawSectionId.toString()) ?? 0;

    final rawYear = json['year'];
    final year =
        rawYear is int ? rawYear : int.tryParse(rawYear?.toString() ?? '') ?? DateTime.now().year;

    // meeting_days: puede llegar como List, String CSV o String JSON
    List<String> meetingDays = [];
    final raw = json['meeting_days'];
    if (raw is List) {
      meetingDays = raw.map((e) => e.toString()).toList();
    } else if (raw is String && raw.isNotEmpty) {
      // Intentar como JSON primero
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          meetingDays = decoded.map((e) {
            if (e is Map) return e['day']?.toString() ?? e.toString();
            return e.toString();
          }).toList();
        } else {
          meetingDays = raw.split(',').map((e) => e.trim()).toList();
        }
      } catch (_) {
        meetingDays = raw.split(',').map((e) => e.trim()).toList();
      }
    }

    // meeting_schedule: JSON estructurado [{day, time}, ...]
    List<MeetingSchedule> schedule = [];
    final rawSchedule = json['meeting_schedule'];
    if (rawSchedule is List) {
      schedule = rawSchedule
          .whereType<Map<String, dynamic>>()
          .map(MeetingSchedule.fromJson)
          .toList();
    } else if (rawSchedule is String && rawSchedule.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSchedule);
        if (decoded is List) {
          schedule = decoded
              .whereType<Map<String, dynamic>>()
              .map(MeetingSchedule.fromJson)
              .toList();
        }
      } catch (_) {}
    }

    // Si no hay schedule pero hay meeting_days, construir schedule sin hora
    if (schedule.isEmpty && meetingDays.isNotEmpty) {
      schedule = meetingDays
          .map((d) => MeetingSchedule(day: d, time: '09:00'))
          .toList();
    }

    EnrollmentStatus status = EnrollmentStatus.active;
    final rawStatus = (json['status'] as String?)?.toLowerCase();
    if (rawStatus == 'inactive') status = EnrollmentStatus.inactive;
    if (rawStatus == 'pending') status = EnrollmentStatus.pending;

    DateTime? createdAt;
    final rawCreated = json['created_at'];
    if (rawCreated is String) createdAt = DateTime.tryParse(rawCreated);

    // Nuevos campos opcionales
    final rawSouls = json['souls_target'];
    final soulsTarget = rawSouls is int ? rawSouls : int.tryParse(rawSouls?.toString() ?? '');

    bool? fee;
    final rawFee = json['fee'];
    if (rawFee is bool) fee = rawFee;
    if (rawFee is int) fee = rawFee != 0;

    final rawFeeAmount = json['fee_amount'];
    final feeAmount = rawFeeAmount is num ? rawFeeAmount.toDouble() : null;

    // Deputy directors: puede ser lista de IDs
    List<String> deputyIds = [];
    final rawDeputy = json['deputy_director_ids'];
    if (rawDeputy is List) {
      deputyIds = rawDeputy.map((e) => e.toString()).toList();
    }

    return EnrollmentModel(
      id: id,
      userId: (json['user_id'] ?? json['created_by'] ?? '').toString(),
      clubSectionId: sectionId,
      year: year,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      long: (json['long'] as num?)?.toDouble(),
      meetingDays: meetingDays,
      meetingSchedule: schedule,
      status: status,
      createdAt: createdAt,
      soulsTarget: soulsTarget,
      fee: fee,
      feeAmount: feeAmount,
      directorId: json['director_id'] as String?,
      deputyDirectorIds: deputyIds,
      secretaryId: json['secretary_id'] as String?,
      treasurerId: json['treasurer_id'] as String?,
      secretaryTreasurerId: json['secretary_treasurer_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final scheduleJson = meetingSchedule.map((s) => s.toJson()).toList();
    return {
      'id': id,
      'user_id': userId,
      'club_section_id': clubSectionId,
      'year': year,
      'address': address,
      'lat': lat,
      'long': long,
      'meeting_days': meetingDays,
      'meeting_schedule': scheduleJson,
      'status': status.name,
      if (soulsTarget != null) 'souls_target': soulsTarget,
      if (fee != null) 'fee': fee,
      if (feeAmount != null) 'fee_amount': feeAmount,
      if (directorId != null) 'director_id': directorId,
      if (deputyDirectorIds.isNotEmpty) 'deputy_director_ids': deputyDirectorIds,
      if (secretaryId != null) 'secretary_id': secretaryId,
      if (treasurerId != null) 'treasurer_id': treasurerId,
      if (secretaryTreasurerId != null) 'secretary_treasurer_id': secretaryTreasurerId,
    };
  }
}
