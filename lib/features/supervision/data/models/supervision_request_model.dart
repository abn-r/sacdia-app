import '../../domain/entities/supervision_request.dart';

/// Tolerant parsers for `GET /requests/{transfers|assignments}` items and the
/// review responses. Never throw: missing or malformed fields become null/''.
class SupervisionRequestModel extends SupervisionRequest {
  const SupervisionRequestModel({
    required super.kind,
    required super.id,
    required super.status,
    required super.personName,
    required super.personId,
    super.createdAt,
    super.reviewedAt,
    super.reviewerName,
    super.reviewComment,
    super.fromClubName,
    super.fromSectionLabel,
    super.toClubName,
    super.toSectionLabel,
    super.reason,
    super.roleName,
    super.clubName,
    super.sectionLabel,
    super.requestedByName,
  });

  factory SupervisionRequestModel.fromTransferJson(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final from = _map(json['from_section']);
    final to = _map(json['to_section']);
    final user = _map(json['user']);
    return SupervisionRequestModel(
      kind: SupervisionRequestKind.transfer,
      id: _str(json['transfer_request_id']) ?? '',
      status: SupervisionRequestStatus.parse(json['status']),
      personName: _personName(user),
      personId: _str(json['user_id']) ?? _str(user?['user_id']) ?? '',
      createdAt: _date(json['created_at']),
      reviewedAt: _date(json['reviewed_at']),
      reviewerName: _nullableName(_map(json['reviewer'])),
      reviewComment: _str(json['review_comment']),
      fromClubName: _clubName(from),
      fromSectionLabel: _sectionLabel(from),
      toClubName: _clubName(to),
      toSectionLabel: _sectionLabel(to),
      reason: _str(json['reason']),
    );
  }

  factory SupervisionRequestModel.fromAssignmentJson(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final section = _map(json['club_section']);
    final user = _map(json['user']);
    final role = _map(json['role']);
    return SupervisionRequestModel(
      kind: SupervisionRequestKind.assignment,
      id: _str(json['request_id']) ?? '',
      status: SupervisionRequestStatus.parse(json['status']),
      personName: _personName(user),
      personId: _str(json['user_id']) ?? _str(user?['user_id']) ?? '',
      createdAt: _date(json['created_at']),
      reviewedAt: _date(json['reviewed_at']),
      reviewerName: _nullableName(_map(json['approver'])),
      reviewComment: _str(json['comment']),
      roleName: _str(role?['role_name']),
      clubName: _clubName(section),
      sectionLabel: _sectionLabel(section),
      requestedByName: _nullableName(_map(json['requester'])),
    );
  }

  static Map<String, dynamic>? _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static String _personName(Map<String, dynamic>? user) =>
      _nullableName(user) ?? '';

  static String? _nullableName(Map<String, dynamic>? user) {
    if (user == null) return null;
    final name = [_str(user['name']), _str(user['paternal_last_name'])]
        .whereType<String>()
        .join(' ')
        .trim();
    return name.isEmpty ? null : name;
  }

  static String? _clubName(Map<String, dynamic>? section) =>
      _str(_map(section?['clubs'])?['name']);

  static String? _sectionLabel(Map<String, dynamic>? section) =>
      _str(_map(section?['club_types'])?['name']);
}
