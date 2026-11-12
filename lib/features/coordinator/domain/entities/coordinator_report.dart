import 'report_compliance.dart';

/// One monthly club report the coordinator can read
/// (GET /monthly-reports/admin/list, one per club section).
class CoordinatorReport {
  const CoordinatorReport({
    required this.id,
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

  /// Raw backend status: draft | generated | submitted.
  final String status;

  /// Absent: the monthly admin list exposes club_name only.
  final int? clubId;
  final String? clubName;
  final int? clubTypeId;
  final String? clubTypeName;
  final int? year;

  /// Month (1-12).
  final int? period;
  final int? ecclesiasticalYearId;
  final DateTime? submittedAt;

  /// Whether the backend serves a PDF for this report: once generated.
  bool get hasPdf => status == 'generated' || status == 'submitted';

  /// Whether this report counts as delivered for compliance.
  bool get isSubmitted => status == 'submitted';
}

/// Matches report rows to the compliance clubs.
///
/// Monthly rows only carry the club name and club type, so they match by
/// name, and only when that name is unique among [clubs], so an ambiguous
/// name never shows another club's PDF.
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
