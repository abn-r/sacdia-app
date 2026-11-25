/// Harness for the territorial operations and clubs views: fake repositories
/// that record their calls, entity builders and a pump whose router has
/// landing routes for the screens those views push.
///
/// Reuses the user, auth fake and localization setup of
/// `supervision_view_test_harness.dart` (read only).
library;

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_operations.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_clubs_repository.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_operations_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_clubs_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_operations_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../../coordinator/coordinator_test_harness.dart';
import 'supervision_view_test_harness.dart';

const kViewTerritoryCap = 'clubs.view_territory';

const ServerFailure kTerritoryBoom = ServerFailure(message: 'boom');
const AuthFailure kTerritoryForbidden = AuthFailure(message: 'nope', code: 403);

// ── Operations builders ─────────────────────────────────────────────────────

SupervisionOperationsMetrics metrics({
  int clubsTotal = 10,
  int operationalClubs = 8,
  int nonOperationalClubs = 2,
  int operationalSections = 12,
  double? operationalRatePct = 80,
  int peopleActive = 320,
  int accountsActive = 210,
  int classEnrollments = 150,
  int classDistinctPeople = 140,
  List<SupervisionClassEnrollments> classes = const [],
  int reportsExpected = 12,
  int reportsSubmitted = 9,
  int reportsMissing = 3,
  double? reportsCoveragePct = 75,
  int? honorsPendingReview = 4,
  int? honorsApproved = 30,
  bool honorsAvailable = true,
  int activitiesRegistered = 25,
}) =>
    SupervisionOperationsMetrics(
      clubsTotal: clubsTotal,
      clubsActive: clubsTotal,
      clubsInactive: 0,
      operationalClubs: operationalClubs,
      nonOperationalClubs: nonOperationalClubs,
      operationalSections: operationalSections,
      operationalRatePct: operationalRatePct,
      peopleActive: peopleActive,
      accountsActive: accountsActive,
      accountsInactive: 0,
      classEnrollments: classEnrollments,
      classDistinctPeople: classDistinctPeople,
      classes: classes,
      reportsExpected: reportsExpected,
      reportsSubmitted: reportsSubmitted,
      reportsDraft: 0,
      reportsGenerated: 0,
      reportsMissing: reportsMissing,
      reportsCoveragePct: reportsCoveragePct,
      honorsInProgress: null,
      honorsPendingReview: honorsPendingReview,
      honorsApproved: honorsApproved,
      honorsAvailable: honorsAvailable,
      activitiesRegistered: activitiesRegistered,
      activitiesJoint: 0,
      activitiesSections: 0,
      pendingTotal: 0,
    );

SupervisionOperationsChild opsChild(
  int id,
  String name,
  SupervisionTerritoryLevel level, {
  SupervisionOperationsMetrics? m,
}) =>
    SupervisionOperationsChild(
      id: id,
      name: name,
      level: level,
      metrics: m ?? metrics(),
    );

SupervisionOperationsDashboard dashboard({
  SupervisionTerritoryLevel level = SupervisionTerritoryLevel.union,
  int? scopeId = 1,
  String scopeName = 'Unión Norte',
  List<SupervisionScopeNode> path = const [],
  SupervisionOperationsPeriod? period,
  SupervisionOperationsMetrics? summary,
  List<SupervisionOperationsChild> children = const [],
}) =>
    SupervisionOperationsDashboard(
      scope: SupervisionOperationsScope(
        level: level,
        id: scopeId,
        name: scopeName,
        path: path,
      ),
      period: period ?? reportingPeriod(),
      computedAt: null,
      summary: summary ?? metrics(),
      children: children,
    );

SupervisionOperationsPeriod reportingPeriod({
  int? reportYear = 2026,
  int? reportMonth = 10,
  DateTime? yearStart,
  DateTime? yearEnd,
}) =>
    SupervisionOperationsPeriod(
      yearId: 1,
      yearStart: yearStart,
      yearEnd: yearEnd,
      reportYear: reportYear,
      reportMonth: reportMonth,
    );

SupervisionClassEnrollments classRow(
  int id,
  String name, {
  int clubTypeId = 1,
  String clubTypeName = 'Conquistadores',
  int count = 5,
}) =>
    SupervisionClassEnrollments(
      classId: id,
      className: name,
      clubTypeId: clubTypeId,
      clubTypeName: clubTypeName,
      displayOrder: id,
      enrollmentCount: count,
    );

// ── Clubs builders ──────────────────────────────────────────────────────────

SupervisionClubSection clubSection(
  int id,
  String typeName, {
  bool active = true,
  int? soulsTarget,
}) =>
    SupervisionClubSection(
      id: id,
      clubTypeId: id,
      typeName: typeName,
      active: active,
      soulsTarget: soulsTarget,
    );

SupervisionClubListItem clubItem(
  int id, {
  String? name,
  bool active = true,
  String church = 'Iglesia Central',
  String district = 'Distrito 1',
  String localField = 'Asociación Norte',
  List<SupervisionClubSection>? sections,
}) =>
    SupervisionClubListItem(
      id: id,
      name: name ?? 'Club $id',
      active: active,
      churchName: church,
      districtName: district,
      localFieldName: localField,
      sections: sections ?? [clubSection(1, 'Conquistadores')],
    );

SupervisionClubPage clubPage(
  List<SupervisionClubListItem> items, {
  int page = 1,
  int? total,
  bool hasMore = false,
}) =>
    SupervisionClubPage(
      items: items,
      page: page,
      total: total ?? items.length,
      hasMore: hasMore,
    );

SupervisionClubProfile clubProfile({
  int id = 7,
  String name = 'Club Orión',
  bool active = true,
  String? address = 'Calle 1 #23',
  String church = 'Iglesia Central',
  String district = 'Distrito 1',
  String localField = 'Asociación Norte',
  List<SupervisionClubSection>? sections,
}) =>
    SupervisionClubProfile(
      id: id,
      name: name,
      active: active,
      description: null,
      address: address,
      churchName: church,
      districtName: district,
      localFieldName: localField,
      sections: sections ?? const [],
    );

SupervisionClubOverview clubOverview({
  double? attendance = 87.5,
  int activeMembers = 40,
  int invested = 6,
  int pending = 2,
  List<SupervisionClubEvent> events = const [],
}) =>
    SupervisionClubOverview(
      attendanceAverage: attendance,
      activeMembers: activeMembers,
      investedThisYear: invested,
      pendingRequests: pending,
      upcomingEvents: events,
    );

SupervisionClubLeader leader(
  String name, {
  String role = 'x',
  String? section,
}) =>
    SupervisionClubLeader(
      userId: name,
      fullName: name,
      roleName: role,
      sectionName: section,
    );

SupervisionClubSummary clubSummary({
  SupervisionClubProfile? profile,
  SupervisionClubOverview? overview,
  SupervisionClubLeadership? leadership,
}) =>
    SupervisionClubSummary(
      profile: profile ?? clubProfile(),
      overview: overview,
      leadership: leadership,
    );

// ── Fake repositories ───────────────────────────────────────────────────────

class FakeOperationsRepo implements SupervisionOperationsRepository {
  final queries = <SupervisionOperationsQuery>[];

  Future<Either<Failure, SupervisionOperationsDashboard>> Function(
    SupervisionOperationsQuery query,
  ) onDashboard = (_) async => Right(dashboard());

  @override
  Future<Either<Failure, SupervisionOperationsDashboard>> getDashboard(
    SupervisionOperationsQuery query, {
    RequestCancelToken? cancelToken,
  }) {
    queries.add(query);
    return onDashboard(query);
  }
}

class ClubsCall {
  ClubsCall(this.filter, this.search, this.page);
  final SupervisionClubActiveFilter filter;
  final String search;
  final int page;
}

class FakeClubsRepo implements SupervisionClubsRepository {
  final calls = <ClubsCall>[];
  final summaryCalls = <int>[];

  Future<Either<Failure, SupervisionClubPage>> Function(ClubsCall call)
      onClubs = (_) async => Right(clubPage([clubItem(1)]));
  Future<Either<Failure, SupervisionClubSummary>> Function(int id) onSummary =
      (_) async => Right(clubSummary());

  @override
  Future<Either<Failure, SupervisionClubPage>> getClubs({
    required SupervisionClubActiveFilter filter,
    required String search,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) {
    final call = ClubsCall(filter, search, page);
    calls.add(call);
    return onClubs(call);
  }

  @override
  Future<Either<Failure, SupervisionClubSummary>> getClubSummary(
    int clubId, {
    RequestCancelToken? cancelToken,
  }) {
    summaryCalls.add(clubId);
    return onSummary(clubId);
  }
}

// ── Pump ────────────────────────────────────────────────────────────────────

/// Pumps [home] at `/`. `/supervision/operations` renders `ops:<uri>` and
/// `/supervision/clubs/:clubId` renders `club:<id>`, so a push is visible as
/// text.
Future<void> pumpTerritoryApp(
  WidgetTester tester, {
  required Widget home,
  FakeOperationsRepo? opsRepo,
  FakeClubsRepo? clubsRepo,
  List<String> capabilities = const [kSupervisionAppView],
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  } else {
    useTallSurface(tester);
  }
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(
        path: '/supervision/operations',
        builder: (_, state) => Text('ops:${state.uri}'),
      ),
      GoRoute(
        path: '/supervision/clubs/:clubId',
        builder: (_, state) => Text('club:${state.pathParameters['clubId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => FakeSupervisionAuthNotifier(
            supervisionUser(capabilities: capabilities),
          ),
        ),
        if (opsRepo != null)
          supervisionOperationsRepositoryProvider.overrideWithValue(opsRepo),
        if (clubsRepo != null)
          supervisionClubsRepositoryProvider.overrideWithValue(clubsRepo),
      ],
      child: localized(
        (context) => MaterialApp.router(
          routerConfig: router,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler:
                  textScale == null ? null : TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}
