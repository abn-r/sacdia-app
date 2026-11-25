import 'package:equatable/equatable.dart';

enum SupervisionTerritoryLevel {
  all,
  division,
  union,
  localField,
  club,
  coordinator,
  unknown,
}

/// Territory the dashboard is asked for; all null = the actor's own scope.
class SupervisionOperationsQuery extends Equatable {
  const SupervisionOperationsQuery({
    this.divisionId,
    this.unionId,
    this.localFieldId,
  });

  final int? divisionId;
  final int? unionId;
  final int? localFieldId;

  bool get isOwnScope =>
      divisionId == null && unionId == null && localFieldId == null;

  @override
  List<Object?> get props => [divisionId, unionId, localFieldId];
}

class SupervisionScopeNode extends Equatable {
  const SupervisionScopeNode({
    required this.level,
    required this.id,
    required this.name,
  });

  final SupervisionTerritoryLevel level;
  final int id;
  final String name;

  @override
  List<Object?> get props => [level, id, name];
}

class SupervisionOperationsScope extends Equatable {
  const SupervisionOperationsScope({
    required this.level,
    required this.id,
    required this.name,
    required this.path,
  });

  final SupervisionTerritoryLevel level;
  final int? id;
  final String name;
  final List<SupervisionScopeNode> path;

  @override
  List<Object?> get props => [level, id, name, path];
}

class SupervisionOperationsPeriod extends Equatable {
  const SupervisionOperationsPeriod({
    required this.yearId,
    required this.yearStart,
    required this.yearEnd,
    required this.reportYear,
    required this.reportMonth,
  });

  final int yearId;
  final DateTime? yearStart;
  final DateTime? yearEnd;
  final int? reportYear;
  final int? reportMonth;

  bool get hasReportingMonth => reportYear != null && reportMonth != null;

  @override
  List<Object?> get props =>
      [yearId, yearStart, yearEnd, reportYear, reportMonth];
}

class SupervisionClassEnrollments extends Equatable {
  const SupervisionClassEnrollments({
    required this.classId,
    required this.className,
    required this.clubTypeId,
    required this.clubTypeName,
    required this.displayOrder,
    required this.enrollmentCount,
  });

  final int classId;
  final String className;
  final int clubTypeId;
  final String clubTypeName;
  final int displayOrder;
  final int enrollmentCount;

  @override
  List<Object?> get props => [
        classId,
        className,
        clubTypeId,
        clubTypeName,
        displayOrder,
        enrollmentCount,
      ];
}

class SupervisionOperationsMetrics extends Equatable {
  const SupervisionOperationsMetrics({
    required this.clubsTotal,
    required this.clubsActive,
    required this.clubsInactive,
    required this.operationalClubs,
    required this.nonOperationalClubs,
    required this.operationalSections,
    required this.operationalRatePct,
    required this.peopleActive,
    required this.accountsActive,
    required this.accountsInactive,
    required this.classEnrollments,
    required this.classDistinctPeople,
    required this.classes,
    required this.reportsExpected,
    required this.reportsSubmitted,
    required this.reportsDraft,
    required this.reportsGenerated,
    required this.reportsMissing,
    required this.reportsCoveragePct,
    required this.honorsInProgress,
    required this.honorsPendingReview,
    required this.honorsApproved,
    required this.honorsAvailable,
    required this.activitiesRegistered,
    required this.activitiesJoint,
    required this.activitiesSections,
    required this.pendingTotal,
  });

  final int clubsTotal;
  final int clubsActive;
  final int clubsInactive;
  final int operationalClubs;
  final int nonOperationalClubs;
  final int operationalSections;
  final double? operationalRatePct;
  final int peopleActive;
  final int accountsActive;
  final int accountsInactive;
  final int classEnrollments;
  final int classDistinctPeople;

  /// Server order kept.
  final List<SupervisionClassEnrollments> classes;
  final int reportsExpected;
  final int reportsSubmitted;
  final int reportsDraft;
  final int reportsGenerated;
  final int reportsMissing;
  final double? reportsCoveragePct;
  final int? honorsInProgress;
  final int? honorsPendingReview;
  final int? honorsApproved;

  /// False when the server could not attribute honors (`unavailable`).
  final bool honorsAvailable;
  final int activitiesRegistered;
  final int activitiesJoint;
  final int activitiesSections;

  /// Sum of the five queues, a null queue counting as 0.
  final int pendingTotal;

  bool get hasGap => reportsMissing > 0 || nonOperationalClubs > 0;

  static const SupervisionOperationsMetrics empty =
      SupervisionOperationsMetrics(
    clubsTotal: 0,
    clubsActive: 0,
    clubsInactive: 0,
    operationalClubs: 0,
    nonOperationalClubs: 0,
    operationalSections: 0,
    operationalRatePct: null,
    peopleActive: 0,
    accountsActive: 0,
    accountsInactive: 0,
    classEnrollments: 0,
    classDistinctPeople: 0,
    classes: [],
    reportsExpected: 0,
    reportsSubmitted: 0,
    reportsDraft: 0,
    reportsGenerated: 0,
    reportsMissing: 0,
    reportsCoveragePct: null,
    honorsInProgress: null,
    honorsPendingReview: null,
    honorsApproved: null,
    honorsAvailable: false,
    activitiesRegistered: 0,
    activitiesJoint: 0,
    activitiesSections: 0,
    pendingTotal: 0,
  );

  @override
  List<Object?> get props => [
        clubsTotal,
        clubsActive,
        clubsInactive,
        operationalClubs,
        nonOperationalClubs,
        operationalSections,
        operationalRatePct,
        peopleActive,
        accountsActive,
        accountsInactive,
        classEnrollments,
        classDistinctPeople,
        classes,
        reportsExpected,
        reportsSubmitted,
        reportsDraft,
        reportsGenerated,
        reportsMissing,
        reportsCoveragePct,
        honorsInProgress,
        honorsPendingReview,
        honorsApproved,
        honorsAvailable,
        activitiesRegistered,
        activitiesJoint,
        activitiesSections,
        pendingTotal,
      ];
}

class SupervisionOperationsChild extends Equatable {
  const SupervisionOperationsChild({
    required this.id,
    required this.name,
    required this.level,
    required this.metrics,
  });

  final int id;
  final String name;
  final SupervisionTerritoryLevel level;
  final SupervisionOperationsMetrics metrics;

  @override
  List<Object?> get props => [id, name, level, metrics];
}

class SupervisionOperationsDashboard extends Equatable {
  const SupervisionOperationsDashboard({
    required this.scope,
    required this.period,
    required this.computedAt,
    required this.summary,
    required this.children,
  });

  final SupervisionOperationsScope scope;
  final SupervisionOperationsPeriod period;
  final DateTime? computedAt;
  final SupervisionOperationsMetrics summary;

  /// Sorted: territories with gaps first, then by severity.
  final List<SupervisionOperationsChild> children;

  @override
  List<Object?> get props => [scope, period, computedAt, summary, children];
}
