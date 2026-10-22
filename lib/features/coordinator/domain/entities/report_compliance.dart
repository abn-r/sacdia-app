/// Read-only report compliance of the coordinator's clubs for one
/// ecclesiastical year (GET /reports/compliance).
library;

/// Kind of club report. Monthly reports belong to a club SECTION; quarterly
/// and annual reports belong to the club.
enum CoordinatorReportKind {
  monthly,
  quarterly,
  annual;

  /// Whether the kind is split into periods (months / quarters).
  bool get hasPeriods => this != CoordinatorReportKind.annual;
}

/// Compliance outcome of a club (or of a whole period) for one report kind.
enum ReportComplianceStatus {
  /// Every expected report was submitted (finalized for quarterly/annual).
  submitted,

  /// Some report is missing but its due date has not passed yet.
  pending,

  /// Some report is missing and its due date already passed.
  overdue,

  /// Nothing is expected yet: the period is still open.
  notDue,
}

/// expected / submitted / pending / overdue counts. A period counts once it
/// has ended (or once its report was submitted early).
class ReportCounts {
  const ReportCounts({
    this.expected = 0,
    this.submitted = 0,
    this.pending = 0,
    this.overdue = 0,
  });

  static const zero = ReportCounts();

  final int expected;
  final int submitted;
  final int pending;
  final int overdue;

  /// The worst outcome wins: overdue, then pending, then submitted.
  ReportComplianceStatus get status {
    if (overdue > 0) return ReportComplianceStatus.overdue;
    if (pending > 0) return ReportComplianceStatus.pending;
    if (expected > 0) return ReportComplianceStatus.submitted;
    return ReportComplianceStatus.notDue;
  }

  ReportCounts operator +(ReportCounts other) => ReportCounts(
        expected: expected + other.expected,
        submitted: submitted + other.submitted,
        pending: pending + other.pending,
        overdue: overdue + other.overdue,
      );
}

/// One month (or quarter) of the ecclesiastical year with its totals.
class ReportCompliancePeriod {
  const ReportCompliancePeriod({
    required this.year,
    required this.index,
    required this.counts,
    this.dueAt,
  });

  final int year;

  /// Month (1-12) or quarter (1-4), depending on the report kind.
  final int index;
  final ReportCounts counts;
  final DateTime? dueAt;
}

class ComplianceSection {
  const ComplianceSection({
    required this.clubSectionId,
    required this.clubTypeId,
    this.clubTypeName,
  });

  final int clubSectionId;
  final int clubTypeId;
  final String? clubTypeName;
}

class ClubReportCompliance {
  const ClubReportCompliance({
    required this.clubId,
    required this.clubName,
    this.localFieldName,
    this.sections = const [],
    this.monthly = ReportCounts.zero,
    this.quarterly = ReportCounts.zero,
    this.annual = ReportCounts.zero,
  });

  final int clubId;
  final String clubName;
  final String? localFieldName;
  final List<ComplianceSection> sections;
  final ReportCounts monthly;
  final ReportCounts quarterly;
  final ReportCounts annual;

  ReportCounts countsFor(CoordinatorReportKind kind) => switch (kind) {
        CoordinatorReportKind.monthly => monthly,
        CoordinatorReportKind.quarterly => quarterly,
        CoordinatorReportKind.annual => annual,
      };
}

class ReportCompliance {
  const ReportCompliance({
    required this.asOf,
    required this.ecclesiasticalYearId,
    required this.clubCount,
    required this.monthly,
    required this.quarterly,
    required this.annual,
    this.monthlyPeriods = const [],
    this.quarterlyPeriods = const [],
    this.clubs = const [],
  });

  final DateTime asOf;
  final int ecclesiasticalYearId;
  final int clubCount;
  final ReportCounts monthly;
  final ReportCounts quarterly;
  final ReportCounts annual;
  final List<ReportCompliancePeriod> monthlyPeriods;
  final List<ReportCompliancePeriod> quarterlyPeriods;
  final List<ClubReportCompliance> clubs;

  /// Every kind added together (hub summary).
  ReportCounts get overall => monthly + quarterly + annual;

  ReportCounts countsFor(CoordinatorReportKind kind) => switch (kind) {
        CoordinatorReportKind.monthly => monthly,
        CoordinatorReportKind.quarterly => quarterly,
        CoordinatorReportKind.annual => annual,
      };

  List<ReportCompliancePeriod> periodsFor(CoordinatorReportKind kind) =>
      switch (kind) {
        CoordinatorReportKind.monthly => monthlyPeriods,
        CoordinatorReportKind.quarterly => quarterlyPeriods,
        CoordinatorReportKind.annual => const [],
      };

  /// Periods that already started as of [asOf], newest first. Future months
  /// carry no expectation, so they are not offered as filters.
  List<ReportCompliancePeriod> startedPeriodsFor(CoordinatorReportKind kind) {
    final started = periodsFor(kind)
        .where((p) => !periodStart(kind, p).isAfter(asOf))
        .toList();
    return started.reversed.toList();
  }

  /// Default period: the newest one with something expected, else the newest
  /// started one. Null for annual reports or when no period started.
  ReportCompliancePeriod? defaultPeriodFor(CoordinatorReportKind kind) {
    final started = startedPeriodsFor(kind);
    if (started.isEmpty) return null;
    return started.firstWhere(
      (p) => p.counts.expected > 0,
      orElse: () => started.first,
    );
  }
}

/// First instant (UTC) of [period].
DateTime periodStart(
  CoordinatorReportKind kind,
  ReportCompliancePeriod period,
) {
  final month =
      kind == CoordinatorReportKind.quarterly ? (period.index - 1) * 3 + 1 : 1;
  return DateTime.utc(
    period.year,
    kind == CoordinatorReportKind.monthly ? period.index : month,
  );
}
