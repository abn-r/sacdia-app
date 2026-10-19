import '../../domain/entities/dependent.dart';

/// Parseo tolerante de los contratos de `/guardianships` (`data` ya sin el
/// envelope `{status, data}`). Un campo ausente nunca debe tumbar la pantalla.
abstract final class FamilyJson {
  static DateTime? _date(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  static String? _string(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString();
    return value.isEmpty ? null : value;
  }

  static int? _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static Map<String, dynamic>? _map(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : null;

  static DependentSummary summary(Map<String, dynamic> json) {
    final guardianship = _map(json['guardianship']) ?? const {};
    final relationship = _map(guardianship['relationship_type']);
    final membership = _map(json['club_membership']);

    return DependentSummary(
      userId: json['user_id'].toString(),
      name: _string(json['name']),
      paternalLastName: _string(json['paternal_last_name']),
      maternalLastName: _string(json['maternal_last_name']),
      birthday: _date(json['birthday']),
      age: _int(json['age']),
      userImage: _string(json['user_image']),
      postRegisterComplete: json['post_register_complete'] == true,
      frozen: json['frozen'] == true,
      guardianship: DependentGuardianship(
        guardianshipId: guardianship['guardianship_id'].toString(),
        isPrimary: guardianship['is_primary'] == true,
        relationshipType: relationship == null
            ? null
            : RelationshipRef(
                id: relationship['relationship_type_id'].toString(),
                name: _string(relationship['name']) ?? '',
              ),
        consentStatus: GuardianConsentStatus.parse(
          guardianship['consent_status'],
        ),
        verifiedAt: _date(guardianship['verified_at']),
        evidenceUploaded: guardianship['evidence_uploaded'] == true,
      ),
      clubMembership: membership == null
          ? null
          : DependentClubMembership(
              assignmentId: membership['assignment_id'].toString(),
              status: _string(membership['status']) ?? 'pending',
              clubSectionId: _int(membership['club_section_id']),
              clubName: _string(membership['club_name']),
              clubTypeName: _string(membership['club_type_name']),
            ),
    );
  }

  static DependentDetail detail(Map<String, dynamic> json) {
    final guardians = json['guardians'];
    return DependentDetail(
      summary: summary(json),
      guardians: guardians is List
          ? guardians
              .whereType<Map>()
              .map((g) => _guardian(Map<String, dynamic>.from(g)))
              .toList(growable: false)
          : const [],
    );
  }

  static DependentGuardian _guardian(Map<String, dynamic> json) {
    return DependentGuardian(
      guardianshipId: json['guardianship_id'].toString(),
      userId: _string(json['user_id']),
      displayName: _string(json['display_name']) ?? '—',
      relationshipTypeName: _string(json['relationship_type_name']),
      isPrimary: json['is_primary'] == true,
      isCustodian: json['is_custodian'] == true,
      consentStatus: GuardianConsentStatus.parse(json['consent_status']),
      isMe: json['is_me'] == true,
    );
  }

  /// `GET /guardianships/me/dependents` -> `{dependents, limits}`.
  static FamilyOverview overview(Map<String, dynamic> json) {
    final list = json['dependents'];
    final limits = _map(json['limits']);
    return FamilyOverview(
      dependents: list is List
          ? list
              .whereType<Map>()
              .map((d) => summary(Map<String, dynamic>.from(d)))
              .toList(growable: false)
          : const [],
      // Si el servidor no informa el límite se usa el de la especificación.
      maxDependents: _int(limits?['max_dependents']) ?? 10,
    );
  }

  static IssuedLinkCode linkCode(Map<String, dynamic> json) {
    return IssuedLinkCode(
      code: json['code'].toString(),
      expiresAt: _date(json['expires_at']) ??
          DateTime.now().add(const Duration(hours: 72)),
    );
  }

  static RevokeResult revoke(Map<String, dynamic> json) {
    return RevokeResult(
      guardianshipId: json['guardianship_id'].toString(),
      outcome: DependentOutcome.parse(json['dependent_outcome']),
    );
  }

  static List<DeletionImpactEntry> deletionImpact(Map<String, dynamic> json) {
    final list = json['dependents'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((raw) {
      final entry = Map<String, dynamic>.from(raw);
      return DeletionImpactEntry(
        userId: entry['user_id'].toString(),
        displayName: _string(entry['display_name']) ?? '—',
        outcome: DependentOutcome.parse(entry['outcome']),
      );
    }).toList(growable: false);
  }
}
