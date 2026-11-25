import '../../domain/entities/supervision_club.dart';

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String? _str(Object? v) {
  if (v == null || v is Map || v is List) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _text(Object? v) => _str(v) ?? '';

int? _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool _bool(Object? v) => v == true || v == 'true' || v == 1;

final RegExp _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Date-only strings become local midnight (no timezone shift).
DateTime? _date(Object? v) {
  if (v is! String) return null;
  final s = v.trim();
  final m = _dateOnly.firstMatch(s);
  if (m != null) {
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
  return DateTime.tryParse(s)?.toLocal();
}

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.map(_map).whereType<Map<String, dynamic>>().toList()
    : const [];

Object? _unwrap(Object? raw) =>
    raw is Map && raw['data'] is Map ? raw['data'] : raw;

class SupervisionClubModel {
  const SupervisionClubModel._();

  static SupervisionClubSection? _section(Map<String, dynamic> j) {
    final id = _int(j['club_section_id']);
    if (id == null) return null;
    final type = _map(j['club_types']);
    return SupervisionClubSection(
      id: id,
      clubTypeId: _int(j['club_type_id']) ?? _int(type?['club_type_id']) ?? 0,
      typeName: _text(type?['name']),
      active: _bool(j['active']),
      soulsTarget: _int(j['souls_target']),
      phone: _str(j['phone']),
      email: _str(j['email']),
    );
  }

  static List<SupervisionClubSection> _sections(Object? v) =>
      _maps(v).map(_section).whereType<SupervisionClubSection>().toList();

  /// Null only when the item has no usable id.
  static SupervisionClubListItem? tryParseListItem(Object? raw) {
    final json = _map(raw);
    final id = _int(json?['club_id']);
    if (json == null || id == null) return null;
    return SupervisionClubListItem(
      id: id,
      name: _text(json['name']),
      active: _bool(json['active']),
      churchName: _text(_map(json['churches'])?['name']),
      districtName: _text(_map(json['districts'])?['name']),
      localFieldName: _text(_map(json['local_fields'])?['name']),
      sections: _sections(json['club_sections']),
    );
  }

  /// Parses the `{data: [...], meta: {...}}` list response.
  static SupervisionClubPage parsePage(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final meta = _map(json['meta']);
    final items = (json['data'] is List ? json['data'] as List : const [])
        .map(tryParseListItem)
        .whereType<SupervisionClubListItem>()
        .toList();
    final page = _int(meta?['page']) ?? 1;
    final total = _int(meta?['total']) ?? items.length;
    final hasNext = meta?['hasNextPage'];
    return SupervisionClubPage(
      items: items,
      page: page,
      total: total,
      hasMore: hasNext != null ? _bool(hasNext) : false,
    );
  }

  /// Accepts a bare object or `{data: {...}}`. Null when there is no id.
  static SupervisionClubProfile? tryParseProfile(Object? raw) {
    final json = _map(_unwrap(raw));
    final id = _int(json?['club_id']);
    if (json == null || id == null) return null;
    return SupervisionClubProfile(
      id: id,
      name: _text(json['name']),
      active: _bool(json['active']),
      description: _str(json['description']),
      address: _str(json['address']),
      churchName: _text(_map(json['churches'])?['name']),
      districtName: _text(_map(json['districts'])?['name']),
      localFieldName: _text(_map(json['local_fields'])?['name']),
      sections: _sections(json['club_sections']),
    );
  }

  static SupervisionClubEvent? _event(Map<String, dynamic> j) {
    final id = _int(j['activity_id']);
    if (id == null) return null;
    return SupervisionClubEvent(
      id: id,
      name: _text(j['name']),
      date: _date(j['activity_date']),
      sectionName: _str(j['section_name']),
    );
  }

  /// Parses `{status, data: O}` or `O`; `score` is ignored.
  static SupervisionClubOverview parseOverview(Object? raw) {
    final json = _map(_unwrap(raw)) ?? const <String, dynamic>{};
    final funnel = _map(json['funnel']);
    return SupervisionClubOverview(
      attendanceAverage: _double(json['attendance_average']),
      activeMembers: _int(funnel?['active_members']) ?? 0,
      investedThisYear: _int(funnel?['investidos_year']) ?? 0,
      pendingRequests: _int(funnel?['pending_requests']) ?? 0,
      upcomingEvents: _maps(json['upcoming_events'])
          .map(_event)
          .whereType<SupervisionClubEvent>()
          .toList(),
    );
  }

  static SupervisionClubLeader? _leader(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final userId = _text(json['user_id']);
    final fullName = [
      _str(json['name']),
      _str(json['paternal_last_name']),
      _str(json['maternal_last_name']),
    ].whereType<String>().join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (userId.isEmpty && fullName.isEmpty) return null;
    return SupervisionClubLeader(
      userId: userId,
      fullName: fullName,
      roleName: _text(json['role_name']),
      sectionName: _str(json['section_name']),
    );
  }

  static List<SupervisionClubLeader> _leaders(Object? v) => v is List
      ? v.map(_leader).whereType<SupervisionClubLeader>().toList()
      : const [];

  /// Parses `{status, data: L}` or `L`; `others` is ignored.
  static SupervisionClubLeadership parseLeadership(Object? raw) {
    final json = _map(_unwrap(raw)) ?? const <String, dynamic>{};
    return SupervisionClubLeadership(
      director: _leader(json['director']),
      deputies: _leaders(json['deputies']),
      secretaries: _leaders(json['secretaries']),
    );
  }
}
