import 'report_compliance.dart';

/// One club report the coordinator can read (admin list endpoints).
///
/// Monthly items come from GET /monthly-reports/admin/list (one per club
/// section); quarterly and annual ones from GET /admin/quarterly-reports and
/// GET /admin/annual-reports (one per club).
class CoordinatorReport {
  const CoordinatorReport({
    required this.id,
    required this.kind,
    required this.status,
    this.clubId,
    this.clubName,
    this.clubTypeId,
    this.clubTypeName,
    this.year,
    this.period,
    this.ecclesiasticalYearId,
    this.submittedAt,
  });

  final int id;
  final CoordinatorReportKind kind;

  /// Raw backend status: draft | generated | submitted (monthly),
  /// draft | finalized | archived (quarterly / annual).
  final String status;

  /// Absent on monthly items: the monthly admin list exposes club_name only.
  final int? clubId;
  final String? clubName;
  final int? clubTypeId;
  final String? clubTypeName;
  final int? year;

  /// Month (1-12) or quarter (1-4); null for annual reports.
  final int? period;
  final int? ecclesiasticalYearId;

  /// submitted_at (monthly) or finalized_at (quarterly / annual).
  final DateTime? submittedAt;

  /// Whether the backend serves a PDF for this report: monthly reports once
  /// generated, quarterly/annual once an admin finalized them.
  bool get hasPdf => switch (kind) {
        CoordinatorReportKind.monthly =>
          status == 'generated' || status == 'submitted',
        _ => status == 'finalized' || status == 'archived',
      };

  /// Whether this report counts as delivered for compliance.
  bool get isSubmitted => switch (kind) {
        CoordinatorReportKind.monthly => status == 'submitted',
        _ => status == 'finalized' || status == 'archived',
      };
}

/// Matches report rows to the compliance clubs.
///
/// Quarterly / annual rows carry the club id. Monthly rows only carry the club
/// name and club type, so they match by name — and only when that name is
/// unique among [clubs], so an ambiguous name never shows another club's PDF.
Map<int, List<CoordinatorReport>> groupReportsByClub(
  List<ClubReportCompliance> clubs,
  List<CoordinatorReport> reports,
) {
  final byName = <String, List<int>>{};
  for (final club in clubs) {
    byName.putIfAbsent(_nameKey(club.clubName), () => []).add(club.clubId);
  }
  final known = {for (final club in clubs) club.clubId};

  final grouped = <int, List<CoordinatorReport>>{};
  for (final report in reports) {
    int? clubId = report.clubId;
    if (clubId == null && report.clubName != null) {
      final candidates = byName[_nameKey(report.clubName!)];
      if (candidates != null && candidates.length == 1) {
        clubId = candidates.single;
      }
    }
    if (clubId == null || !known.contains(clubId)) continue;
    grouped.putIfAbsent(clubId, () => []).add(report);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => (a.clubTypeId ?? 0).compareTo(b.clubTypeId ?? 0));
  }
  return grouped;
}

String _nameKey(String name) => name.trim().toLowerCase();
