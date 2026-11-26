import '../../domain/entities/supervision_operations.dart';

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String _text(Object? v) {
  if (v == null || v is Map || v is List) return '';
  return v.toString().trim();
}

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

SupervisionTerritoryLevel _level(Object? v) => switch (v) {
      'all' => SupervisionTerritoryLevel.all,
      'division' => SupervisionTerritoryLevel.division,
      'union' => SupervisionTerritoryLevel.union,
      'local_field' => SupervisionTerritoryLevel.localField,
      'club' => SupervisionTerritoryLevel.club,
      'coordinator' => SupervisionTerritoryLevel.coordinator,
      _ => SupervisionTerritoryLevel.unknown,
    };

class SupervisionOperationsModel {
  const SupervisionOperationsModel._();

  static SupervisionClassEnrollments? _parseClass(Map<String, dynamic> j) {
    final id = _int(j['class_id']);
    if (id == null) return null;
    return SupervisionClassEnrollments(
      classId: id,
      className: _text(j['class_name']),
      clubTypeId: _int(j['club_type_id']) ?? 0,
      clubTypeName: _text(j['club_type_name']),
      displayOrder: _int(j['display_order']) ?? 0,
      enrollmentCount: _int(j['enrollment_count']) ?? 0,
    );
  }

  /// Parses a metrics block (the summary or a child row); never throws.
  static SupervisionOperationsMetrics parseMetrics(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final clubs = _map(json['administrative_clubs']);
    final ops = _map(json['operations']);
    final people = _map(json['people']);
    final accounts = _map(people?['platform_accounts']);
    final classes = _map(json['classes']);
    final reports = _map(json['monthly_reports']);
    final honors = _map(json['honors']);
    final activities = _map(json['activities']);
    final queues = _map(json['queues']);

    int n(Map<String, dynamic>? m, String k) => _int(m?[k]) ?? 0;

    final pendingTotal = n(queues, 'role_assignments_pending') +
        n(queues, 'transfers_pending') +
        n(queues, 'class_validations_pending') +
        n(queues, 'honors_review_pending') +
        n(queues, 'annual_folders_pending_union');

    return SupervisionOperationsMetrics(
      clubsTotal: n(clubs, 'total'),
      clubsActive: n(clubs, 'active'),
      clubsInactive: n(clubs, 'inactive'),
      operationalClubs: n(ops, 'operational_clubs'),
      nonOperationalClubs: n(ops, 'non_operational_clubs'),
      operationalSections: n(ops, 'operational_sections'),
      operationalRatePct: _double(ops?['operational_rate_pct']),
      peopleActive: n(people, 'institutionally_active'),
      accountsActive: n(accounts, 'active'),
      accountsInactive: n(accounts, 'inactive'),
      classEnrollments: n(classes, 'total_enrollments'),
      classDistinctPeople: n(classes, 'distinct_people'),
      classes: _maps(classes?['by_class'])
          .map(_parseClass)
          .whereType<SupervisionClassEnrollments>()
          .toList(),
      reportsExpected: n(reports, 'expected_sections'),
      reportsSubmitted: n(reports, 'submitted_sections'),
      reportsDraft: n(reports, 'draft_sections'),
      reportsGenerated: n(reports, 'generated_sections'),
      reportsMissing: n(reports, 'missing_sections'),
      reportsCoveragePct: _double(reports?['coverage_pct']),
      honorsInProgress: _int(honors?['in_progress']),
      honorsPendingReview: _int(honors?['pending_review']),
      honorsApproved: _int(honors?['approved']),
      honorsAvailable:
          honors != null && _text(honors['attribution']) != 'unavailable',
      activitiesRegistered: n(activities, 'registered'),
      activitiesJoint: n(activities, 'joint_registered'),
      activitiesSections: n(activities, 'distinct_participating_sections'),
      pendingTotal: pendingTotal,
    );
  }

  static SupervisionOperationsChild? _parseChild(Map<String, dynamic> j) {
    final id = _int(j['id']);
    if (id == null) return null;
    return SupervisionOperationsChild(
      id: id,
      name: _text(j['name']),
      level: _level(j['level']),
      metrics: parseMetrics(j),
    );
  }

  static int _byGap(
    SupervisionOperationsChild a,
    SupervisionOperationsChild b,
  ) {
    if (a.metrics.hasGap != b.metrics.hasGap) return a.metrics.hasGap ? -1 : 1;
    final byMissing =
        b.metrics.reportsNotSubmitted.compareTo(a.metrics.reportsNotSubmitted);
    if (byMissing != 0) return byMissing;
    final byNonOp =
        b.metrics.nonOperationalClubs.compareTo(a.metrics.nonOperationalClubs);
    if (byNonOp != 0) return byNonOp;
    final byPending = b.metrics.pendingTotal.compareTo(a.metrics.pendingTotal);
    if (byPending != 0) return byPending;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Parses the unwrapped `data` object; never throws.
  static SupervisionOperationsDashboard parseDashboard(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final meta = _map(json['meta']);
    final scope = _map(meta?['scope']);
    final period = _map(meta?['period']);
    final year = _map(period?['ecclesiastical_year']);
    final month = _map(period?['reporting_month']);

    final path = _maps(scope?['path'])
        .map((p) {
          final id = _int(p['id']);
          if (id == null) return null;
          return SupervisionScopeNode(
            level: _level(p['level']),
            id: id,
            name: _text(p['name']),
          );
        })
        .whereType<SupervisionScopeNode>()
        .toList();

    final reportYear = _int(month?['year']);
    final reportMonth = _int(month?['month']);
    final hasMonth = reportYear != null && reportMonth != null;

    final children = _maps(json['children'])
        .map(_parseChild)
        .whereType<SupervisionOperationsChild>()
        .toList()
      ..sort(_byGap);

    return SupervisionOperationsDashboard(
      scope: SupervisionOperationsScope(
        level: _level(scope?['level']),
        id: _int(scope?['id']),
        name: _text(scope?['name']),
        path: path,
      ),
      period: SupervisionOperationsPeriod(
        yearId: _int(year?['id']) ?? 0,
        yearStart: _date(year?['start_date']),
        yearEnd: _date(year?['end_date']),
        reportYear: hasMonth ? reportYear : null,
        reportMonth: hasMonth ? reportMonth : null,
      ),
      computedAt: _date(meta?['computed_at']),
      summary: parseMetrics(json['summary']),
      children: children,
    );
  }
}
