import 'dart:ui' show Tristate;

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/data/datasources/dashboard_pending_remote_data_source.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_pending.dart';
import 'package:sacdia_app/features/dashboard/domain/repositories/dashboard_pending_repository.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_pending_provider.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/pending_tasks_card.dart';
import 'package:sacdia_app/features/enrollment/presentation/widgets/enrollment_status_card.dart';
import '../../../../support/l10n_test_support.dart';
import '../../../../support/riverpod_test_support.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
        id: 'user-1',
        email: 'user@example.com',
        authorization: AuthorizationSnapshot(
          activeAssignmentId: 'a-1',
          clubAssignments: [
            AuthorizationGrant(
              assignmentId: 'a-1',
              roleName: 'director',
              status: 'active',
            ),
          ],
        ),
      );
}

class _FakePendingRepository implements DashboardPendingRepository {
  _FakePendingRepository(this._result);

  final Either<Failure, DashboardPending> _result;
  int calls = 0;

  @override
  Future<Either<Failure, DashboardPending>> getPending({
    RequestCancelToken? cancelToken,
  }) async {
    calls++;
    return _result;
  }
}

const _report = PendingItem(
  type: PendingItemType.monthlyReport,
  count: 1,
  severity: PendingSeverity.urgent,
  reportStatus: PendingReportStatus.draft,
  daysLeft: 1,
);

const _folder = PendingItem(
  type: PendingItemType.evidenceFolder,
  count: 2,
  severity: PendingSeverity.urgent,
  rejectedCount: 1,
  notSubmittedCount: 1,
);

const _requests = PendingItem(
  type: PendingItemType.membershipRequests,
  count: 3,
  severity: PendingSeverity.warning,
);

const _authorizations = PendingItem(
  type: PendingItemType.investitureAuthorizations,
  count: 7,
  severity: PendingSeverity.info,
);

DashboardPending _pending(List<PendingItem> items) => DashboardPending(
      total: items.fold(0, (sum, i) => sum + i.count),
      urgent: items.where((i) => i.severity == PendingSeverity.urgent).length,
      items: items,
    );

Future<_FakePendingRepository> _pumpCard(
  WidgetTester tester,
  Either<Failure, DashboardPending> result, {
  AnnualEnrollmentTask? enrollmentTask,
}) async {
  final repository = _FakePendingRepository(result);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: SingleChildScrollView(child: PendingTasksCard()),
        ),
      ),
      GoRoute(
        path: RouteNames.homeEvidences,
        builder: (_, __) => const Scaffold(body: Text('evidences screen')),
      ),
    ],
  );
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        dashboardPendingRepositoryProvider.overrideWithValue(repository),
        annualEnrollmentTaskProvider.overrideWith((ref) => enrollmentTask),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repository;
}

void main() {
  setUpAll(loadSpanishTranslations);

  group('PendingTasksCard', () {
    testWidgets('is collapsed by default and expands on header tap',
        (tester) async {
      await _pumpCard(
        tester,
        Right(_pending(const [_folder, _report, _requests, _authorizations])),
      );

      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('13 por atender'), findsOneWidget);
      expect(find.text('2 urgentes'), findsOneWidget);
      // Collapsed: no rows yet.
      expect(find.text('Solicitudes de membresía'), findsNothing);
      expect(find.text('Informe mensual'), findsNothing);

      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();

      expect(find.text('Solicitudes de membresía'), findsOneWidget);
      expect(find.text('Carpeta de evidencias'), findsOneWidget);
      expect(find.text('Informe mensual'), findsOneWidget);
      expect(find.text('Autorizaciones de investidura'), findsOneWidget);

      // Evidence folder subtitle and plain count badges.
      expect(find.text('1 rechazada · 1 sin enviar'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitudes de membresía'), findsNothing);
    });

    testWidgets('header is a button that reports its expanded state',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCard(tester, Right(_pending(const [_requests])));

      final header = find.bySemanticsLabel('Pendientes, 3 por atender');
      expect(header, findsOneWidget);
      var data = tester.getSemantics(header).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded, Tristate.isFalse);

      await tester.tap(header);
      await tester.pumpAndSettle();
      data = tester.getSemantics(header).getSemanticsData();
      expect(data.flagsCollection.isExpanded, Tristate.isTrue);
      handle.dispose();
    });

    for (final badgeCase in <({int daysLeft, String text})>[
      (daysLeft: 1, text: 'Vence en 1 día'),
      (daysLeft: 5, text: 'Vence en 5 días'),
      (daysLeft: 0, text: 'Vence hoy'),
      (daysLeft: -2, text: 'Venció hace 2 días'),
    ]) {
      testWidgets(
        'monthly report badge reads "${badgeCase.text}" '
        'for days_left=${badgeCase.daysLeft}',
        (tester) async {
          await _pumpCard(
            tester,
            Right(
              _pending([
                PendingItem(
                  type: PendingItemType.monthlyReport,
                  count: 1,
                  severity: PendingSeverity.warning,
                  reportStatus: PendingReportStatus.missing,
                  daysLeft: badgeCase.daysLeft,
                ),
              ]),
            ),
          );
          await tester.tap(find.text('Pendientes'));
          await tester.pumpAndSettle();

          expect(find.text(badgeCase.text), findsOneWidget);
        },
      );
    }

    testWidgets('row tap pushes the mapped route', (tester) async {
      await _pumpCard(tester, Right(_pending(const [_folder])));
      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Carpeta de evidencias'));
      await tester.pumpAndSettle();

      expect(find.text('evidences screen'), findsOneWidget);
    });

    test('maps every item type to its app route', () {
      expect(
        pendingRouteFor(PendingItemType.membershipRequests),
        RouteNames.homeMemberRequests,
      );
      expect(
        pendingRouteFor(PendingItemType.evidenceFolder),
        RouteNames.homeEvidences,
      );
      expect(
        pendingRouteFor(PendingItemType.monthlyReport),
        RouteNames.homeReports,
      );
      expect(
        pendingRouteFor(PendingItemType.investitureAuthorizations),
        RouteNames.investitureAuthorize,
      );
    });

    testWidgets('adds the annual enrollment as the first row and counts it',
        (tester) async {
      await _pumpCard(
        tester,
        Right(_pending(const [_requests])),
        enrollmentTask: const AnnualEnrollmentTask(),
      );

      expect(find.text('4 por atender'), findsOneWidget);

      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();

      final enrollment = find.text('Inscripción anual pendiente');
      final requests = find.text('Solicitudes de membresía');
      expect(enrollment, findsOneWidget);
      expect(
        tester.getTopLeft(enrollment).dy,
        lessThan(tester.getTopLeft(requests).dy),
      );
    });

    testWidgets('shows the enrollment row alone when the server has nothing',
        (tester) async {
      await _pumpCard(
        tester,
        Right(_pending(const [])),
        enrollmentTask: const AnnualEnrollmentTask(),
      );

      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('1 por atender'), findsOneWidget);
      // The enrollment row is urgent and counts in the header.
      expect(find.text('1 urgente'), findsOneWidget);
    });

    testWidgets('renders nothing when there is nothing to attend',
        (tester) async {
      await _pumpCard(tester, Right(_pending(const [])));

      expect(find.byType(PendingTasksPanel), findsNothing);
      expect(find.text('Pendientes'), findsNothing);
    });

    testWidgets('renders nothing (no error UI) when the endpoint fails',
        (tester) async {
      final repository = await _pumpCard(
        tester,
        const Left(ServerFailure(message: 'Not Found', code: 404)),
      );

      expect(repository.calls, 1);
      expect(find.byType(PendingTasksPanel), findsNothing);
      expect(find.text('Pendientes'), findsNothing);
      expect(find.textContaining('Not Found'), findsNothing);
    });
  });

  group('DashboardPendingRemoteDataSourceImpl', () {
    Dio dioReturning(int status, Object? body) {
      final dio = Dio();
      dio.httpClientAdapter = _StubAdapter(status, body);
      return dio;
    }

    test('parses a 200 payload (and tolerates a data envelope)', () async {
      final payload = {
        'total': 3,
        'urgent': 0,
        'items': [
          {'type': 'membership_requests', 'count': 3, 'severity': 'warning'},
        ],
      };
      for (final body in [
        payload,
        {'data': payload},
      ]) {
        final ds = DashboardPendingRemoteDataSourceImpl(
          dio: dioReturning(200, body),
          baseUrl: 'http://localhost/api/v1',
        );
        final pending = await ds.getPending();
        expect(pending.total, 3);
        expect(pending.items.single.type, PendingItemType.membershipRequests);
      }
    });

    test('maps a 404 to a ServerException the repository turns into Left',
        () async {
      final ds = DashboardPendingRemoteDataSourceImpl(
        dio: dioReturning(404, {'message': 'Cannot GET'}),
        baseUrl: 'http://localhost/api/v1',
      );
      await expectLater(ds.getPending(), throwsA(anything));
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      _encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  static String _encode(Object? value) {
    if (value is Map) {
      return '{${value.entries.map((e) => '"${e.key}":${_encode(e.value)}').join(',')}}';
    }
    if (value is List) return '[${value.map(_encode).join(',')}]';
    if (value is String) return '"$value"';
    return '$value';
  }
}
