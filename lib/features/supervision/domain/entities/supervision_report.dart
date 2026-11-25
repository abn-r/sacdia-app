import 'package:equatable/equatable.dart';

/// (year, month 1-12) of a monthly report period.
typedef SupervisionPeriodKey = ({int year, int month});

/// expected / submitted / pending / overdue counts of a period or a club.
class SupervisionReportCounts extends Equatable {
  const SupervisionReportCounts({
    this.expected = 0,
    this.submitted = 0,
    this.pending = 0,
    this.overdue = 0,
  });

  static const zero = SupervisionReportCounts();

  final int expected;
  final int submitted;
  final int pending;
  final int overdue;

  @override
  List<Object?> get props => [expected, submitted, pending, overdue];
}

class SupervisionReportPeriod extends Equatable {
  const SupervisionReportPeriod({
    required this.year,
    required this.month,
    this.dueAt,
    this.counts = SupervisionReportCounts.zero,
  });

  final int year;
  final int month;
  final DateTime? dueAt;
  final SupervisionReportCounts counts;

  SupervisionPeriodKey get key => (year: year, month: month);

  @override
  List<Object?> get props => [year, month, dueAt, counts];
}

/// Periods of the active year the selector offers.
class SupervisionReportPeriods extends Equatable {
  const SupervisionReportPeriods({this.started = const []});

  /// Months whose first day is not after `as_of`, newest first.
  final List<SupervisionReportPeriod> started;

  /// Newest started month with something expected, else the newest started
  /// one. Null when no month started.
  SupervisionReportPeriod? get defaultPeriod {
    if (started.isEmpty) return null;
    return started.firstWhere(
      (p) => p.counts.expected > 0,
      orElse: () => started.first,
    );
  }

  @override
  List<Object?> get props => [started];
}

class SupervisionClubCompliance extends Equatable {
  const SupervisionClubCompliance({
    required this.clubId,
    this.clubName = '',
    this.localFieldName = '',
    this.sectionNames = const [],
    this.counts = SupervisionReportCounts.zero,
  });

  final int clubId;
  final String clubName;

  /// Empty when the club has no local field.
  final String localFieldName;

  /// Non-blank club type names, without duplicates.
  final List<String> sectionNames;
  final SupervisionReportCounts counts;

  @override
  List<Object?> get props =>
      [clubId, clubName, localFieldName, sectionNames, counts];
}

class SupervisionCompliancePage extends Equatable {
  const SupervisionCompliancePage({
    this.totals = SupervisionReportCounts.zero,
    this.clubCount = 0,
    this.clubs = const [],
    this.page = 1,
    this.total = 0,
    this.hasMore = false,
  });

  /// `totals.monthly` of the response.
  final SupervisionReportCounts totals;

  /// `totals.clubs`.
  final int clubCount;
  final List<SupervisionClubCompliance> clubs;
  final int page;

  /// Clubs matching the query across all pages.
  final int total;
  final bool hasMore;

  @override
  List<Object?> get props => [totals, clubCount, clubs, page, total, hasMore];
}

enum SupervisionReportStatus {
  draft,
  generated,
  submitted,
  unknown;

  static SupervisionReportStatus parse(Object? raw) {
    switch (raw is String ? raw.trim().toLowerCase() : null) {
      case 'draft':
        return draft;
      case 'generated':
        return generated;
      case 'submitted':
        return submitted;
      default:
        return unknown;
    }
  }
}

class SupervisionMonthlyReport extends Equatable {
  const SupervisionMonthlyReport({
    required this.id,
    this.status = SupervisionReportStatus.unknown,
    this.year = 0,
    this.month = 0,
    this.clubName = '',
    this.clubTypeName = '',
    this.localFieldName = '',
    this.submitterName,
    this.generatedAt,
    this.submittedAt,
    this.memberCount,
  });

  /// UUID.
  final String id;
  final SupervisionReportStatus status;
  final int year;
  final int month;
  final String clubName;
  final String clubTypeName;
  final String localFieldName;
  final String? submitterName;
  final DateTime? generatedAt;
  final DateTime? submittedAt;
  final int? memberCount;

  bool get hasPdf =>
      status == SupervisionReportStatus.generated ||
      status == SupervisionReportStatus.submitted;

  @override
  List<Object?> get props => [
        id,
        status,
        year,
        month,
        clubName,
        clubTypeName,
        localFieldName,
        submitterName,
        generatedAt,
        submittedAt,
        memberCount,
      ];
}

class SupervisionReportPage extends Equatable {
  const SupervisionReportPage({
    this.items = const [],
    this.page = 1,
    this.total = 0,
    this.hasMore = false,
  });

  final List<SupervisionMonthlyReport> items;
  final int page;
  final int total;
  final bool hasMore;

  @override
  List<Object?> get props => [items, page, total, hasMore];
}
