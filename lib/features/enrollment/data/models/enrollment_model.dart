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
    required super.meetingDays,
    required super.status,
    super.createdAt,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['enrollment_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    final rawSectionId = json['club_section_id'] ?? json['section_id'];
    final sectionId =
        rawSectionId is int ? rawSectionId : int.tryParse(rawSectionId.toString()) ?? 0;

    final rawYear = json['year'];
    final year =
        rawYear is int ? rawYear : int.tryParse(rawYear?.toString() ?? '') ?? DateTime.now().year;

    // meeting_days puede llegar como List o como String CSV
    List<String> meetingDays = [];
    final raw = json['meeting_days'];
    if (raw is List) {
      meetingDays = raw.map((e) => e.toString()).toList();
    } else if (raw is String && raw.isNotEmpty) {
      meetingDays = raw.split(',').map((e) => e.trim()).toList();
    }

    EnrollmentStatus status = EnrollmentStatus.active;
    final rawStatus = (json['status'] as String?)?.toLowerCase();
    if (rawStatus == 'inactive') status = EnrollmentStatus.inactive;
    if (rawStatus == 'pending') status = EnrollmentStatus.pending;

    DateTime? createdAt;
    final rawCreated = json['created_at'];
    if (rawCreated is String) createdAt = DateTime.tryParse(rawCreated);

    return EnrollmentModel(
      id: id,
      userId: (json['user_id'] ?? '').toString(),
      clubSectionId: sectionId,
      year: year,
      address: json['address'] as String?,
      meetingDays: meetingDays,
      status: status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'club_section_id': clubSectionId,
        'year': year,
        'address': address,
        'meeting_days': meetingDays,
        'status': status.name,
      };
}
