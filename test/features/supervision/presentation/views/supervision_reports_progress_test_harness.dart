/// Harness for the territorial «Informes mensuales» and «Progreso anual»
/// views: fake repositories that record every call, entity builders and a pump
/// for the annual-progress view with a signed-in user of any territory.
///
/// Reuses the auth fake, user and localization setup of
/// `supervision_view_test_harness.dart` (read only).
library;

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_annual_progress.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_report.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_annual_progress_repository.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_reports_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_annual_progress_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/club_type_model.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../../coordinator/coordinator_test_harness.dart';
import 'supervision_view_test_harness.dart';

const ServerFailure kBoom = ServerFailure(message: 'boom');
const AuthFailure kForbidden = AuthFailure(message: 'nope', code: 403);

// ── Reports: builders ───────────────────────────────────────────────────────

SupervisionReportCounts counts({
  int expected = 0,
  int submitted = 0,
  int pending = 0,
  int overdue = 0,
}) =>
    SupervisionReportCounts(
      expected: expected,
      submitted: submitted,
      pending: pending,
      overdue: overdue,
    );

SupervisionReportPeriod period(
  int year,
  int month, {
  DateTime? dueAt,
  SupervisionReportCounts? counts,
}) =>
    SupervisionReportPeriod(
      year: year,
      month: month,
      dueAt: dueAt,
      counts: counts ?? const SupervisionReportCounts(),
    );

SupervisionReportPeriods periods(List<SupervisionReportPeriod> started) =>
    SupervisionReportPeriods(started: started);

SupervisionClubCompliance clubCompliance(
  int id, {
  String? name,
  String localField = 'Asociación Norte',
  List<String> sections = const ['Conquistadores'],
  SupervisionReportCounts? counts,
}) =>
    SupervisionClubCompliance(
      clubId: id,
      clubName: name ?? 'Club $id',
      localFieldName: localField,
      sectionNames: sections,
      counts: counts ?? const SupervisionReportCounts(),
    );

SupervisionCompliancePage compliancePage(
  List<SupervisionClubCompliance> clubs, {
  SupervisionReportCounts totals = const SupervisionReportCounts(),
  int page = 1,
  int? total,
  bool hasMore = false,
}) =>
    SupervisionCompliancePage(
      totals: totals,
      clubCount: clubs.length,
      clubs: clubs,
      page: page,
      total: total ?? clubs.length,
      hasMore: hasMore,
    );

SupervisionMonthlyReport report(
  String id, {
  SupervisionReportStatus status = SupervisionReportStatus.submitted,
  String? clubName,
  String clubTypeName = 'Conquistadores',
  String localFieldName = 'Asociación Norte',
  DateTime? submittedAt,
}) =>
    SupervisionMonthlyReport(
      id: id,
      status: status,
      clubName: clubName ?? 'Club $id',
      clubTypeName: clubTypeName,
      localFieldName: localFieldName,
      submittedAt: submittedAt,
    );

SupervisionReportPage reportPage(
  List<SupervisionMonthlyReport> items, {
  int page = 1,
  int? total,
  bool hasMore = false,
}) =>
    SupervisionReportPage(
      items: items,
      page: page,
      total: total ?? items.length,
      hasMore: hasMore,
    );

// ── Reports: fake repository ────────────────────────────────────────────────

typedef PagedCall = ({SupervisionPeriodKey period, int page});

class FakeReportsRepo implements SupervisionReportsRepository {
  int periodsCalls = 0;
  final complianceCalls = <PagedCall>[];
  final reportCalls = <PagedCall>[];
  final pdfCalls = <String>[];

  Future<Either<Failure, SupervisionReportPeriods>> Function() onPeriods =
      () async => Right(
            periods([
              period(2026, 10, counts: counts(expected: 3, submitted: 2)),
            ]),
          );
  Future<Either<Failure, SupervisionCompliancePage>> Function(PagedCall call)
      onCompliance = (_) async => Right(compliancePage([clubCompliance(1)]));
  Future<Either<Failure, SupervisionReportPage>> Function(PagedCall call)
      onReports = (_) async => Right(reportPage([report('r1')]));
  Future<Either<Failure, String>> Function(String id) onPdf =
      (_) async => const Right('/tmp/informe.pdf');

  @override
  Future<Either<Failure, SupervisionReportPeriods>> getPeriods({
    RequestCancelToken? cancelToken,
  }) {
    periodsCalls++;
    return onPeriods();
  }

  @override
  Future<Either<Failure, SupervisionCompliancePage>> getCompliance({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) {
    final call = (period: period, page: page);
    complianceCalls.add(call);
    return onCompliance(call);
  }

  @override
  Future<Either<Failure, SupervisionReportPage>> getReports({
    required SupervisionPeriodKey period,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) {
    final call = (period: period, page: page);
    reportCalls.add(call);
    return onReports(call);
  }

  @override
  Future<Either<Failure, String>> downloadReportPdf(
    String reportId, {
    RequestCancelToken? cancelToken,
  }) {
    pdfCalls.add(reportId);
    return onPdf(reportId);
  }
}

// ── Annual progress: builders ───────────────────────────────────────────────

EcclesiasticalYearModel progressYear({String name = '2025-2026'}) =>
    EcclesiasticalYearModel(
      ecclesiasticalYearId: 7,
      name: name,
      startDate: DateTime(2025, 7, 1),
      endDate: DateTime(2026, 6, 30),
      active: true,
    );

const kConquistadores = ClubTypeModel(clubTypeId: 2, name: 'Conquistadores');
const kAventureros = ClubTypeModel(clubTypeId: 1, name: 'Aventureros');

SupervisionTerritoryOption territoryOption(
  int id,
  String name, {
  int? clubsCount,
  bool? configured,
  int? goldOrBetterCount,
}) =>
    SupervisionTerritoryOption(
      id: id,
      name: name,
      clubsCount: clubsCount,
      configured: configured,
      goldOrBetterCount: goldOrBetterCount,
    );

SupervisionProgressComponent component(
  String key, {
  String? label,
  double earned = 10,
  double max = 20,
  double pct = 50,
}) =>
    SupervisionProgressComponent(
      key: key,
      label: label ?? 'Componente $key',
      earnedPoints: earned,
      maxPoints: max,
      progressPercentage: pct,
    );

SupervisionProgressAxis axis(
  String key, {
  String? label,
  double earned = 0,
  double max = 0,
  List<SupervisionProgressComponent> components = const [],
}) =>
    SupervisionProgressAxis(
      key: key,
      label: label ?? 'Eje $key',
      earnedPoints: earned,
      maxPoints: max,
      components: components,
    );

SupervisionClubProgress clubProgress(
  int id, {
  String? name,
  double points = 320,
  double max = 500,
  double pct = 64,
  SupervisionProgressTier? current = const SupervisionProgressTier(
    name: 'Oro',
  ),
  SupervisionProgressTier? next,
  List<SupervisionProgressAxis> axes = const [],
  List<SupervisionProgressComponent> components = const [],
}) =>
    SupervisionClubProgress(
      clubId: id,
      clubSectionId: id * 10,
      clubName: name ?? 'Club $id',
      currentPoints: points,
      maxPoints: max,
      progressPercentage: pct,
      currentTier: current,
      nextTier: next,
      axes: axes,
      components: components,
    );

// ── Annual progress: fake repository ────────────────────────────────────────

class FakeProgressRepo implements SupervisionAnnualProgressRepository {
  final unionCalls = <int>[];
  final localFieldCalls = <int>[];
  final progressCalls = <SupervisionAnnualProgressQuery>[];

  Future<Either<Failure, List<SupervisionTerritoryOption>>> Function(int id)
      onUnions = (_) async => Right(
          [territoryOption(1, 'Unión Norte'), territoryOption(2, 'Unión Sur')]);
  Future<Either<Failure, List<SupervisionTerritoryOption>>> Function(int id)
      onLocalFields = (_) async => Right([
            territoryOption(10, 'Asociación Este'),
            territoryOption(11, 'Asociación Oeste')
          ]);
  Future<Either<Failure, SupervisionAnnualProgress>> Function(
    SupervisionAnnualProgressQuery query,
  ) onProgress = (_) async => Right(
        SupervisionAnnualProgress(
          configured: true,
          clubs: [clubProgress(1)],
        ),
      );

  @override
  Future<Either<Failure, List<SupervisionTerritoryOption>>> getUnions(
    int divisionId, {
    RequestCancelToken? cancelToken,
  }) {
    unionCalls.add(divisionId);
    return onUnions(divisionId);
  }

  @override
  Future<Either<Failure, List<SupervisionTerritoryOption>>> getLocalFields(
    int unionId, {
    RequestCancelToken? cancelToken,
  }) {
    localFieldCalls.add(unionId);
    return onLocalFields(unionId);
  }

  @override
  Future<Either<Failure, SupervisionAnnualProgress>> getAnnualProgress(
    SupervisionAnnualProgressQuery query, {
    RequestCancelToken? cancelToken,
  }) {
    progressCalls.add(query);
    return onProgress(query);
  }
}

// ── Annual progress: pump ───────────────────────────────────────────────────

/// Supervisor whose territory is [territory] (null = no territory at all).
UserEntity userWithTerritory(AuthorizationTerritory? territory) => UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: true,
      onboardingMode: OnboardingMode.clubExempt,
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        clubAssignments: const [],
        capabilities: const [kSupervisionAppView],
        territory: territory,
      ),
    );

const kDivisionTerritory =
    AuthorizationTerritory(level: 'division', divisionId: 5);
const kUnionTerritory = AuthorizationTerritory(level: 'union', unionId: 3);
const kLocalFieldTerritory = AuthorizationTerritory(
  level: 'local_field',
  unionId: 3,
  localFieldId: 11,
);

final _capturedErrors = <String>[];

/// Fails when the framework caught any exception (overflow, build error),
/// printing the full diagnostics (which widget overflowed) as the reason.
void expectNoException(WidgetTester tester) {
  var count = 0;
  while (tester.takeException() != null) {
    count++;
  }
  expect(count, 0, reason: _capturedErrors.join('\n---\n'));
}

/// Pumps [home] at `/` with `/supervision/annual-progress` as a landing route
/// that renders `landing:<full location>`.
Future<void> pumpProgressApp(
  WidgetTester tester, {
  required Widget home,
  required FakeProgressRepo repo,
  AuthorizationTerritory? territory = kDivisionTerritory,
  EcclesiasticalYearModel? year,
  bool noYear = false,
  List<ClubTypeModel> types = const [kConquistadores],
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
  _capturedErrors.clear();
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    _capturedErrors.add(details.toString());
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(
        path: '/supervision/annual-progress',
        builder: (_, state) => Text('landing:${state.uri}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  final pickedYear = noYear ? null : (year ?? progressYear());
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => FakeSupervisionAuthNotifier(userWithTerritory(territory)),
        ),
        supervisionAnnualProgressRepositoryProvider.overrideWithValue(repo),
        supervisionProgressYearProvider.overrideWith((ref) async => pickedYear),
        clubTypesProvider.overrideWith((ref) async => types),
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
