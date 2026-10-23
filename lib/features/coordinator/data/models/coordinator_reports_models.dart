import '../../domain/entities/coordinator_report.dart';
import '../../domain/entities/report_compliance.dart';

/// Parsers for the coordinator reports endpoints. Every field is read
/// defensively: a missing or mistyped value degrades to null / 0 instead of
/// failing the whole screen.
class ReportComplianceModel {
  const ReportComplianceModel._();

  /// GET /reports/compliance → `data`.
  static ReportCompliance fromJson(Map<String, dynamic> json) {
    final totals = _map(json['totals']);
    final year = _map(json['ecclesiastical_year']);
    final monthly = _map(totals['monthly']);
    final quarterly = _map(totals['quarterly']);

    return ReportCompliance(
      asOf: _date(json['as_of']) ?? DateTime.now().toUtc(),
      ecclesiasticalYearId: _int(year['year_id']) ?? 0,
      clubCount: _int(totals['clubs']) ?? _int(json['total']) ?? 0,
      monthly: countsFromJson(monthly),
      quarterly: countsFromJson(quarterly),
      annual: countsFromJson(_map(totals['annual'])),
      monthlyPeriods: _periods(monthly['by_period'], 'month'),
      quarterlyPeriods: _periods(quarterly['by_period'], 'quarter'),
      clubs: [
        for (final item in _list(json['items'])) _club(item),
      ],
    );
  }

  static ReportCounts countsFromJson(Map<String, dynamic> json) => ReportCounts(
        expected: _int(json['expected']) ?? 0,
        submitted: _int(json['submitted']) ?? 0,
        pending: _int(json['pending']) ?? 0,
        overdue: _int(json['overdue']) ?? 0,
      );

  static List<ReportCompliancePeriod> _periods(Object? raw, String indexKey) =>
      [
        for (final p in _list(raw))
          if (_int(p['year']) != null && _int(p[indexKey]) != null)
            ReportCompliancePeriod(
              year: _int(p['year'])!,
              index: _int(p[indexKey])!,
              dueAt: _date(p['due_at']),
              counts: countsFromJson(p),
            ),
      ];

  static ClubReportCompliance _club(Map<String, dynamic> json) =>
      ClubReportCompliance(
        clubId: _int(json['club_id']) ?? 0,
        clubName: (json['club_name'] as String?)?.trim() ?? '',
        localFieldName: json['local_field_name'] as String?,
        sections: [
          for (final s in _list(json['sections']))
            if (_int(s['club_section_id']) != null)
              ComplianceSection(
                clubSectionId: _int(s['club_section_id'])!,
                clubTypeId: _int(s['club_type_id']) ?? 0,
                clubTypeName: s['club_type_name'] as String?,
              ),
        ],
        monthly: countsFromJson(_map(json['monthly'])),
        quarterly: countsFromJson(_map(json['quarterly'])),
        annual: countsFromJson(_map(json['annual'])),
      );
}

class CoordinatorReportModel {
  const CoordinatorReportModel._();

  /// One item of the monthly / quarterly / annual admin list.
  static CoordinatorReport? fromJson(
    CoordinatorReportKind kind,
    Map<String, dynamic> json,
  ) {
    final id = _int(switch (kind) {
      CoordinatorReportKind.monthly => json['monthly_report_id'],
      CoordinatorReportKind.quarterly => json['quarterly_report_id'],
      CoordinatorReportKind.annual => json['annual_report_id'],
    });
    if (id == null) return null;

    final club = _map(json['club']);
    return CoordinatorReport(
      id: id,
      kind: kind,
      status: (json['status'] as String?) ?? 'draft',
      clubId: _int(json['club_id']) ?? _int(club['club_id']),
      clubName: (json['club_name'] as String?) ?? (club['name'] as String?),
      clubTypeId: _int(json['club_type_id']),
      clubTypeName: json['club_type'] as String?,
      year: _int(json['year']),
      period: switch (kind) {
        CoordinatorReportKind.monthly => _int(json['month']),
        CoordinatorReportKind.quarterly => _int(json['quarter']),
        CoordinatorReportKind.annual => null,
      },
      ecclesiasticalYearId: _int(json['ecclesiastical_year_id']),
      submittedAt: _date(
        kind == CoordinatorReportKind.monthly
            ? json['submitted_at']
            : json['finalized_at'],
      ),
    );
  }
}

/// `{ total, page, limit, items }` page of an admin list.
class CoordinatorReportPage {
  const CoordinatorReportPage({required this.items, required this.total});

  factory CoordinatorReportPage.fromJson(
    CoordinatorReportKind kind,
    Map<String, dynamic> json,
  ) {
    final items = [
      for (final raw in _list(json['items']))
        CoordinatorReportModel.fromJson(kind, raw),
    ].whereType<CoordinatorReport>().toList();
    return CoordinatorReportPage(
      items: items,
      total: _int(json['total']) ?? items.length,
    );
  }

  final List<CoordinatorReport> items;
  final int total;
}

Map<String, dynamic> _map(Object? raw) =>
    raw is Map<String, dynamic> ? raw : const <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? raw) =>
    raw is List ? raw.whereType<Map<String, dynamic>>().toList() : const [];

int? _int(Object? raw) => switch (raw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };

DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
