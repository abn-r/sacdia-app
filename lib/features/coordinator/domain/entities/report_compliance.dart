/// Read-only monthly report compliance of the coordinator's clubs for one
/// ecclesiastical year (GET /reports/compliance).
///
/// Coordinators do not see quarterly or annual reports: the backend answers
/// 403 on those lists, and the compliance totals for them are ignored.
library;

/// Compliance outcome of a club (or of a whole period).
enum ReportComplianceStatus {
  /// Every expected report was submitted.
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

/// One month of the ecclesiastical year with its totals.
class ReportCompliancePeriod {
  const ReportCompliancePeriod({
    required this.year,
    required this.index,
    required this.counts,
    this.dueAt,
  });

  final int year;

  /// Month (1-12).
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
  });

  final int clubId;
  final String clubName;
  final String? localFieldName;
  final List<ComplianceSection> sections;
  final ReportCounts monthly;
}

class ReportCompliance {
  const ReportCompliance({
    required this.asOf,
    required this.ecclesiasticalYearId,
    required this.clubCount,
    required this.monthly,
    this.monthlyPeriods = const [],
    this.clubs = const [],
  });

  final DateTime asOf;
  final int ecclesiasticalYearId;
  final int clubCount;
  final ReportCounts monthly;
  final List<ReportCompliancePeriod> monthlyPeriods;
  final List<ClubReportCompliance> clubs;

  /// Months that already started as of [asOf], newest first. Future months
  /// carry no expectation, so they are not offered as filters.
  List<ReportCompliancePeriod> get startedPeriods {
    final started =
        monthlyPeriods.where((p) => !periodStart(p).isAfter(asOf)).toList();
    return started.reversed.toList();
  }

  /// Default month: the newest one with something expected, else the newest
  /// started one. Null when no month started.
  ReportCompliancePeriod? get defaultPeriod {
    final started = startedPeriods;
    if (started.isEmpty) return null;
    return started.firstWhere(
      (p) => p.counts.expected > 0,
      orElse: () => started.first,
    );
  }
}

/// First instant (UTC) of [period].
DateTime periodStart(ReportCompliancePeriod period) =>
    DateTime.utc(period.year, period.index);
