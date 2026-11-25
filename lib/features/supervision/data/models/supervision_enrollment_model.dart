import '../../domain/entities/supervision_enrollment.dart';

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int? _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

SupervisionPersonRef? _person(Object? v) {
  final m = _map(v);
  if (m == null) return null;
  final id = _str(m['user_id']);
  if (id == null) return null;
  return SupervisionPersonRef(userId: id, name: _str(m['name']) ?? '');
}

class SupervisionEnrollmentModel extends SupervisionEnrollment {
  const SupervisionEnrollmentModel({
    required super.id,
    required super.status,
    super.yearName,
    super.clubName,
    super.clubTypeName,
    super.localFieldName,
    super.address,
    super.meetingDays,
    super.soulsTarget,
    super.hasFee,
    super.feeAmount,
    super.board,
    super.submittedBy,
    super.submittedAt,
    super.createdAt,
    super.reviewedBy,
    super.reviewerRole,
    super.reviewedAt,
    super.decisionReason,
  });

  /// Tolerant parser: missing or malformed fields become null/defaults.
  /// Returns null only when the item has no usable id.
  static SupervisionEnrollmentModel? tryParse(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _str(json['enrollment_id']);
    if (id == null) return null;
    final board = _map(json['board']);
    final deputies = board?['deputies'];
    return SupervisionEnrollmentModel(
      id: id,
      status: SupervisionEnrollmentStatus.parse(_str(json['status'])),
      yearName: _str(_map(json['ecclesiastical_year'])?['name']) ?? '',
      clubName: _str(_map(json['club'])?['name']) ?? '',
      clubTypeName: _str(_map(json['section'])?['club_type_name']) ?? '',
      localFieldName: _str(_map(json['local_field'])?['name']) ?? '',
      address: _str(json['address']),
      meetingDays: _str(json['meeting_days']),
      soulsTarget: _int(json['souls_target']),
      hasFee: json['fee'] == true,
      feeAmount: _double(json['fee_amount']),
      board: SupervisionEnrollmentBoard(
        director: _person(board?['director']),
        deputies: deputies is List
            ? deputies.map(_person).whereType<SupervisionPersonRef>().toList()
            : const [],
        secretary: _person(board?['secretary']),
        treasurer: _person(board?['treasurer']),
        secretaryTreasurer: _person(board?['secretary_treasurer']),
      ),
      submittedBy: _person(json['submitted_by']),
      submittedAt: _date(json['submitted_at']),
      createdAt: _date(json['created_at']),
      reviewedBy: _person(json['reviewed_by']),
      reviewerRole: _str(json['reviewer_role']),
      reviewedAt: _date(json['reviewed_at']),
      decisionReason: _str(json['decision_reason']),
    );
  }

  static SupervisionEnrollmentPage parsePage(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final items = json['items'];
    final meta = _map(json['meta']);
    final counts = _map(meta?['counts']);
    final parsed = items is List
        ? items.map(tryParse).whereType<SupervisionEnrollmentModel>().toList()
        : <SupervisionEnrollment>[];
    return SupervisionEnrollmentPage(
      items: parsed,
      page: _int(meta?['page']) ?? 1,
      limit: _int(meta?['limit']) ?? 20,
      total: _int(meta?['total']) ?? parsed.length,
      counts: SupervisionEnrollmentCounts(
        pending: _int(counts?['pending']) ?? 0,
        approved: _int(counts?['approved']) ?? 0,
        rejected: _int(counts?['rejected']) ?? 0,
      ),
    );
  }
}
