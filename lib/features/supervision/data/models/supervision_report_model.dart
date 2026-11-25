import '../../domain/entities/supervision_report.dart';

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

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.map(_map).whereType<Map<String, dynamic>>().toList()
    : const [];

class SupervisionReportModel {
  const SupervisionReportModel._();

  static SupervisionReportCounts parseCounts(Object? raw) {
    final json = _map(raw);
    if (json == null) return SupervisionReportCounts.zero;
    return SupervisionReportCounts(
      expected: _int(json['expected']) ?? 0,
      submitted: _int(json['submitted']) ?? 0,
      pending: _int(json['pending']) ?? 0,
      overdue: _int(json['overdue']) ?? 0,
    );
  }

  /// Builds the selectable periods from `totals.monthly.by_period` and
  /// `as_of`. Without a usable `as_of` nothing is considered started.
  static SupervisionReportPeriods parsePeriods(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final asOf = DateTime.tryParse(_text(json['as_of']))?.toUtc();
    final monthly = _map(_map(json['totals'])?['monthly']);
    final periods = <SupervisionReportPeriod>[];
    for (final p in _maps(monthly?['by_period'])) {
      final year = _int(p['year']);
      final month = _int(p['month']);
      if (year == null || month == null || month < 1 || month > 12) continue;
      periods.add(SupervisionReportPeriod(
        year: year,
        month: month,
        dueAt: _date(p['due_at']),
        counts: parseCounts(p),
      ));
    }
    if (asOf == null) return const SupervisionReportPeriods();
    final started = periods
        .where((p) => !DateTime.utc(p.year, p.month).isAfter(asOf))
        .toList()
      ..sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        return byYear != 0 ? byYear : b.month.compareTo(a.month);
      });
    return SupervisionReportPeriods(started: started);
  }

  static SupervisionClubCompliance? tryParseClub(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _int(json['club_id']);
    if (id == null) return null;
    final names = <String>[];
    for (final s in _maps(json['sections'])) {
      final name = _str(s['club_type_name']);
      if (name != null && !names.contains(name)) names.add(name);
    }
    return SupervisionClubCompliance(
      clubId: id,
      clubName: _text(json['club_name']),
      localFieldName: _text(json['local_field_name']),
      sectionNames: names,
      counts: parseCounts(json['monthly']),
    );
  }

  static SupervisionCompliancePage parseCompliancePage(
    Object? raw, {
    required int limit,
  }) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final totals = _map(json['totals']);
    final clubs = _maps(json['items'])
        .map(tryParseClub)
        .whereType<SupervisionClubCompliance>()
        .toList();
    final page = _int(json['page']) ?? 1;
    final total = _int(json['total']) ?? clubs.length;
    return SupervisionCompliancePage(
      totals: parseCounts(_map(totals?['monthly'])),
      clubCount: _int(totals?['clubs']) ?? total,
      clubs: clubs,
      page: page,
      total: total,
      hasMore: page * limit < total,
    );
  }

  /// Returns null when the report has no usable id.
  static SupervisionMonthlyReport? tryParseReport(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _str(json['monthly_report_id']);
    if (id == null) return null;
    return SupervisionMonthlyReport(
      id: id,
      status: SupervisionReportStatus.parse(json['status']),
      year: _int(json['year']) ?? 0,
      month: _int(json['month']) ?? 0,
      clubName: _text(json['club_name']),
      clubTypeName: _text(json['club_type']),
      localFieldName: _text(json['local_field']),
      submitterName: _str(json['submitter_name']),
      generatedAt: _date(json['generated_at']),
      submittedAt: _date(json['submitted_at']),
      memberCount: _int(json['member_count']),
    );
  }

  static SupervisionReportPage parseReportPage(
    Object? raw, {
    required int limit,
  }) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final items = _maps(json['items'])
        .map(tryParseReport)
        .whereType<SupervisionMonthlyReport>()
        .toList();
    final page = _int(json['page']) ?? 1;
    final total = _int(json['total']) ?? items.length;
    return SupervisionReportPage(
      items: items,
      page: page,
      total: total,
      hasMore: page * limit < total,
    );
  }
}
