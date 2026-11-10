import '../../domain/entities/role_candidate.dart';

/// Parseo tolerante de `GET .../role-candidates` y `.../role-candidates/:userId`.
///
/// Todo campo opcional del contrato puede venir `null` o ausente. Nunca se lee
/// email ni teléfono: el contrato no los publica y la UI no los muestra.

Map<String, dynamic>? _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : null;

List<Map<String, dynamic>> _maps(Object? raw) => raw is List
    ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

List<String> _strings(Object? raw) => raw is List
    ? raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
    : const [];

int? _int(Object? raw) => raw is num ? raw.toInt() : int.tryParse('$raw');

String? _text(Object? raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

class RoleCandidateModel extends RoleCandidate {
  const RoleCandidateModel({
    required super.userId,
    required super.name,
    super.photoUrl,
    super.age,
    super.gender,
    required super.group,
    super.gmAnnualStatus,
    super.guideMajor,
    super.currentRoles,
    super.serviceYears,
    super.consent,
    super.allowedRoles,
    super.blockedReason,
    super.requirements,
  });

  factory RoleCandidateModel.fromJson(Map<String, dynamic> json) {
    final gm = _map(json['guide_major']);
    final consent = _map(json['consent']);
    return RoleCandidateModel(
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      photoUrl: _text(json['photo_url']),
      age: _int(json['age']),
      gender: _text(json['gender']),
      group: RoleCandidateGroup.parse(json['group']),
      gmAnnualStatus: GmAnnualStatus.parse(json['gm_annual_status']),
      guideMajor: gm == null
          ? null
          : RoleCandidateGuideMajor(
              basis: GuideMajorBasis.parse(gm['basis']),
              investitureYear: _text(gm['investiture_year']),
              advanced: gm['advanced'] == true,
              instructor: gm['instructor'] == true,
            ),
      currentRoles: [
        for (final r in _maps(json['current_roles']))
          if (_text(r['role']) != null)
            RoleCandidateCurrentRole(
              sectionId: _int(r['section_id']) ?? 0,
              clubTypeId: _int(r['club_type_id']),
              clubTypeName: _text(r['club_type_name']),
              role: r['role'].toString(),
            ),
      ],
      serviceYears: _int(json['service_years']),
      consent: consent == null
          ? null
          : RoleCandidateConsent(
              required: consent['required'] == true,
              verified: consent['verified'] == true,
            ),
      allowedRoles: _strings(json['allowed_roles']),
      blockedReason: _text(json['blocked_reason']),
      requirements: [
        for (final r in _maps(json['requirements']))
          RoleRequirement(
            role: _text(r['role']) ?? '',
            type: _text(r['type']) ?? RoleRequirement.counselorTraining,
            mode: RequirementMode.parse(r['mode']),
            status: RequirementStatus.parse(r['status']),
            enforced: r['enforced'] == true,
          ),
      ],
    );
  }
}

RoleSlot _slot(Map<String, dynamic> json) => RoleSlot(
      role: json['role']?.toString() ?? '',
      occupied: _int(json['occupied']) ?? 0,
      max: _int(json['max']),
      holders: _strings(json['holders']),
      blockedBy: _strings(json['blocked_by']),
    );

class RoleCandidatesPageModel extends RoleCandidatesPage {
  const RoleCandidatesPageModel({
    super.section,
    super.slots,
    super.items,
    super.page,
    super.limit,
    super.total,
    super.counts,
  });

  /// [body] es el cuerpo completo (`{status, data: {...}, meta: {...}}`); un
  /// `data` sin envoltorio también se acepta.
  factory RoleCandidatesPageModel.fromJson(Map<String, dynamic> body) {
    final data = _map(body['data']) ?? body;
    final meta = _map(body['meta']) ?? _map(data['meta']) ?? const {};
    final section = _map(data['section']);
    final year = section == null ? null : _map(section['year']);
    final counts = _map(meta['counts']) ?? const {};
    final items = [
      for (final item in _maps(data['items']))
        RoleCandidateModel.fromJson(item),
    ];
    return RoleCandidatesPageModel(
      section: section == null
          ? null
          : RoleCandidatesSection(
              id: _int(section['id']) ?? 0,
              clubTypeId: _int(section['club_type_id']),
              clubTypeName: _text(section['club_type_name']),
              yearName: year == null ? null : _text(year['name']),
              // Only an explicit `false` means there is no GM section.
              hasGmSection: section['has_gm_section'] != false,
            ),
      slots: [
        for (final s in _maps(data['slots']))
          if (_text(s['role']) != null) _slot(s),
      ],
      items: items,
      page: _int(meta['page']) ?? 1,
      limit: _int(meta['limit']) ?? 20,
      total: _int(meta['total']) ?? items.length,
      counts: RoleCandidatesCounts(
        available: _int(counts['available']) ?? 0,
        withRole: _int(counts['with_role']) ?? 0,
        notEnrolled: _int(counts['not_enrolled']) ?? 0,
      ),
    );
  }
}

class RoleCandidateDetailModel extends RoleCandidateDetail {
  const RoleCandidateDetailModel({
    required super.candidate,
    super.roleHistory,
    super.certifications,
    super.insurance,
    super.honorsCount,
    super.credentials,
  });

  factory RoleCandidateDetailModel.fromJson(Map<String, dynamic> body) {
    final data = _map(body['data']) ?? body;
    final insurance = _map(data['insurance']);
    return RoleCandidateDetailModel(
      candidate: RoleCandidateModel.fromJson(data),
      roleHistory: [
        for (final h in _maps(data['role_history']))
          if (_text(h['role']) != null)
            RoleHistoryEntry(
              yearName: _text(h['year_name']),
              clubTypeName: _text(h['club_type_name']),
              role: h['role'].toString(),
            ),
      ],
      certifications: [
        for (final c in _maps(data['certifications']))
          if (_text(c['name']) != null)
            RoleCandidateCertification(
              name: c['name'].toString(),
              status: _text(c['status']),
              certifiedAt:
                  DateTime.tryParse(c['certified_at']?.toString() ?? ''),
            ),
      ],
      insurance: insurance == null
          ? null
          : RoleCandidateInsurance(
              active: insurance['active'] == true,
              expiresAt:
                  DateTime.tryParse(insurance['expires_at']?.toString() ?? ''),
            ),
      honorsCount: _int(data['honors_count']) ?? 0,
      credentials: [
        for (final c in _maps(data['credentials']))
          RoleCandidateCredential(
            type: _text(c['type']) ?? RoleRequirement.counselorTraining,
            status: CredentialStatus.parse(c['status']),
            completedAt: DateTime.tryParse(c['completed_at']?.toString() ?? ''),
            expiresAt: DateTime.tryParse(c['expires_at']?.toString() ?? ''),
          ),
      ],
    );
  }
}
