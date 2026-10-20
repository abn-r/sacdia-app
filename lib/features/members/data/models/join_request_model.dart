import '../../domain/entities/join_request.dart';

/// Modelo de datos de una solicitud de ingreso al club
class JoinRequestModel extends JoinRequest {
  const JoinRequestModel({
    required super.assignmentId,
    required super.userId,
    required super.name,
    super.paternalSurname,
    super.maternalSurname,
    super.avatar,
    super.email,
    required super.status,
    super.requestedAt,
    super.resolvedAt,
    super.consent,
  });

  /// Crea un JoinRequestModel a partir de la respuesta de la API
  factory JoinRequestModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ??
        json['users'] as Map<String, dynamic>? ??
        json;

    JoinRequestStatus status;
    final rawStatus = (json['status'] as String? ?? 'pending').toLowerCase();
    switch (rawStatus) {
      case 'approved':
        status = JoinRequestStatus.approved;
        break;
      case 'rejected':
      case 'denied':
        status = JoinRequestStatus.rejected;
        break;
      default:
        status = JoinRequestStatus.pending;
    }

    final requestId = json['assignment_id']?.toString() ??
        json['club_role_assignment_id']?.toString() ??
        json['id']?.toString() ??
        '';
    final clubSectionId = json['club_section_id']?.toString();
    final assignmentId = (clubSectionId != null && clubSectionId.isNotEmpty)
        ? '$clubSectionId/membership-requests/$requestId'
        : requestId;

    return JoinRequestModel(
      assignmentId: assignmentId,
      userId: user['user_id'] as String? ??
          user['id'] as String? ??
          json['user_id'] as String? ??
          '',
      name: user['name'] as String? ?? '',
      paternalSurname: user['paternal_last_name'] as String? ??
          user['p_lastname'] as String?,
      maternalSurname: user['maternal_last_name'] as String? ??
          user['m_lastname'] as String?,
      avatar: user['user_image'] as String? ?? user['avatar'] as String?,
      email: user['email'] as String?,
      status: status,
      requestedAt: json['requested_at'] != null
          ? DateTime.tryParse(json['requested_at'].toString())
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      consent: _parseConsent(json['consent']),
    );
  }

  /// `consent` es `null` para adultos. Un bloque presente con un estado que no
  /// sea `verified` se lee como pendiente: es el lado seguro (no deja aprobar
  /// sin verificar la ficha).
  static JoinRequestConsent? _parseConsent(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final guardians = map['guardians'];
    return JoinRequestConsent(
      guardianshipId: map['guardianship_id']?.toString(),
      status: JoinRequestConsentStatus.parse(map['status']),
      evidenceUploaded: map['evidence_uploaded'] == true,
      dependent: map['dependent'] != false,
      guardianLinked: map['guardian_linked'] is bool
          ? map['guardian_linked'] as bool
          : null,
      guardians: guardians is List
          ? guardians.whereType<Map>().map((g) {
              final guardian = Map<String, dynamic>.from(g);
              return ConsentGuardianRef(
                displayName: guardian['display_name']?.toString() ?? '—',
                relationshipTypeName:
                    guardian['relationship_type_name']?.toString(),
                isPrimary: guardian['is_primary'] == true,
              );
            }).toList(growable: false)
          : const [],
    );
  }
}
