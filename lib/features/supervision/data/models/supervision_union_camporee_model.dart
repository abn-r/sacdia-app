import '../../domain/entities/supervision_union_camporee.dart';

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
  if (v is String) {
    return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt();
  }
  return null;
}

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

bool _bool(Object? v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v == 'true' || v == 1) return true;
  if (v == 'false' || v == 0) return false;
  return fallback;
}

/// An instant (UTC when the server sends a `Z`).
DateTime? _instant(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Instant shown in local time (audit timestamps).
DateTime? _localInstant(Object? v) => _instant(v)?.toLocal();

final RegExp _datePrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

/// Calendar date of an ISO string at local midnight; the timezone is ignored
/// so a DATE column never shifts a day.
DateTime? _calendarDate(Object? v) {
  if (v is! String) return null;
  final m = _datePrefix.firstMatch(v.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d);
}

/// Name parts joined with single spaces.
String _fullName(Map<String, dynamic>? user) {
  if (user == null) return '';
  return [
    _str(user['name']),
    _str(user['paternal_last_name']),
    _str(user['maternal_last_name']),
  ].whereType<String>().join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.map(_map).whereType<Map<String, dynamic>>().toList()
    : const [];

class SupervisionUnionCamporeeModel {
  const SupervisionUnionCamporeeModel._();

  /// Returns null only when the row has no usable id.
  static SupervisionUnionCamporee? tryParse(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _int(json['union_camporee_id']);
    if (id == null) return null;
    final place = _text(json['union_camporee_place']);
    return SupervisionUnionCamporee(
      id: id,
      name: _text(json['name']),
      description: _str(json['description']),
      startDate: _calendarDate(json['start_date']),
      endDate: _calendarDate(json['end_date']),
      place: place.toLowerCase() == 'lugar' ? '' : place,
      unionName: _text(_map(json['unions'])?['name']),
      active: _bool(json['active'], fallback: true),
      ordersEnabled: _bool(json['orders_enabled']),
      ordersOpensAt: _instant(json['orders_opens_at']),
      ordersDeadline: _instant(json['orders_deadline']),
    );
  }

  /// Parses `{data: [...]}` or a bare array; rows without id are dropped.
  static List<SupervisionUnionCamporee> parseList(Object? raw) {
    final rows = raw is Map ? raw['data'] : raw;
    return _maps(rows)
        .map(tryParse)
        .whereType<SupervisionUnionCamporee>()
        .toList();
  }

  /// A club row from `/pending` (no names available there).
  static SupervisionCamporeePendingClub? tryParsePendingClub(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _int(json['camporee_club_id']);
    if (id == null) return null;
    return SupervisionCamporeePendingClub(
      id: id,
      createdAt: _localInstant(json['created_at']),
    );
  }

  /// A club row from `/clubs?status=pending_approval` (has names).
  static SupervisionCamporeePendingClub? tryParseClubWithNames(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _int(json['camporee_club_id']);
    if (id == null) return null;
    final section = _map(json['club_sections']);
    final registrar = _fullName(_map(json['registrar']));
    return SupervisionCamporeePendingClub(
      id: id,
      clubName: _text(_map(section?['clubs'])?['name']),
      sectionName: _text(_map(section?['club_types'])?['name']),
      registeredByName: registrar.isEmpty ? null : registrar,
      createdAt: _localInstant(json['created_at']),
    );
  }

  static List<SupervisionCamporeePendingClub> parseClubsWithNames(Object? raw) {
    final rows = raw is Map ? raw['data'] : raw;
    return _maps(rows)
        .map(tryParseClubWithNames)
        .whereType<SupervisionCamporeePendingClub>()
        .toList();
  }

  static SupervisionCamporeePendingMember? tryParsePendingMember(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _int(json['camporee_member_id']);
    if (id == null) return null;
    return SupervisionCamporeePendingMember(
      id: id,
      fullName: _fullName(_map(json['users'])),
      clubName: _text(json['club_name']),
      insuranceVerified: _bool(json['insurance_verified']),
      createdAt: _localInstant(json['created_at']),
    );
  }

  static SupervisionCamporeePendingPayment? tryParsePendingPayment(
      Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _str(json['camporee_payment_id']);
    if (id == null) return null;
    final member = _map(json['camporee_member']);
    return SupervisionCamporeePendingPayment(
      id: id,
      memberName: _fullName(_map(member?['users'])),
      clubName: _text(member?['club_name']),
      amount: _double(json['amount']) ?? 0,
      type: SupervisionCamporeePaymentType.parse(json['payment_type']),
      reference: _str(json['reference']),
      notes: _str(json['notes']),
      voucherUrl: _str(json['voucher_url']),
      paidAt: _calendarDate(json['paid_at']),
      createdAt: _localInstant(json['created_at']),
    );
  }

  /// Parses the `/pending` payload (`{clubs, members, payments}`).
  static SupervisionCamporeePending parsePending(Object? raw) {
    final json = _map(raw is Map && raw['data'] is Map ? raw['data'] : raw) ??
        const <String, dynamic>{};
    return SupervisionCamporeePending(
      clubs: _maps(json['clubs'])
          .map(tryParsePendingClub)
          .whereType<SupervisionCamporeePendingClub>()
          .toList(),
      members: _maps(json['members'])
          .map(tryParsePendingMember)
          .whereType<SupervisionCamporeePendingMember>()
          .toList(),
      payments: _maps(json['payments'])
          .map(tryParsePendingPayment)
          .whereType<SupervisionCamporeePendingPayment>()
          .toList(),
    );
  }
}
