import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/access_denied_view.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential_review.dart';
import 'package:sacdia_app/features/service_credentials/presentation/views/service_credential_review_queue_view.dart';
import 'package:sacdia_app/features/service_credentials/presentation/widgets/service_credentials_skeleton.dart';

import '../service_credentials_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeServiceCredentialsRepository repo;
  setUp(() => repo = FakeServiceCredentialsRepository());

  Future<void> open(
    WidgetTester tester, {
    bool settle = true,
    bool allowed = true,
    Size size = const Size(800, 2400),
  }) =>
      pumpCredentialsApp(
        tester,
        home: const ServiceCredentialReviewQueueView(),
        overrides: credentialOverrides(
          repo,
          user: adultUser(capabilities: [if (allowed) reviewerCapability]),
        ),
        routes: [
          GoRoute(
            path: '/service-credentials/review/:credentialId',
            builder: (_, state) => Scaffold(
              body: Text('detail:${state.pathParameters['credentialId']}'),
            ),
          ),
        ],
        settle: settle,
        size: size,
      );

  testWidgets('without the capability the queue is denied and never loads',
      (tester) async {
    await open(tester, allowed: false);
    expect(find.byType(AccessDeniedView), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('shows a skeleton while loading', (tester) async {
    repo.queueGate = Completer<void>();
    await open(tester, settle: false);
    expect(find.byType(ServiceCredentialsSkeleton), findsOneWidget);
    repo.queueGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ServiceCredentialsSkeleton), findsNothing);
  });

  testWidgets('pending queue: rows, group count and tab counts',
      (tester) async {
    repo.queue = (_, __, ___) => Right(reviewPage(
          [
            reviewItem(id: 'a', name: 'Laura Méndez'),
            reviewItem(
              id: 'b',
              name: 'Pedro Ruiz',
              club: 'Club Aurora',
            ),
          ],
          counts: const ReviewCounts(pending: 2, approved: 5, rejected: 1),
        ));
    await open(tester);

    expect(find.text('Laura Méndez'), findsOneWidget);
    expect(find.text('Club Pionero · Curso de consejería (10 horas)'),
        findsOneWidget);
    expect(find.text('Club Aurora · Curso de consejería (10 horas)'),
        findsOneWidget);
    expect(find.text('En revisión · 2'), findsOneWidget);
    // Counts of the three tabs come from meta.counts.
    expect(find.text('5'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(repo.queueRequests.single.status, ReviewStatusFilter.pending);
  });

  testWidgets('empty queue explains there is nothing to review',
      (tester) async {
    await open(tester);
    expect(find.byType(SacEmptyState), findsOneWidget);
    expect(find.text('No hay constancias esperando revisión.'), findsOneWidget);
  });

  testWidgets('tabs request their own status and keep counts on screen',
      (tester) async {
    repo.queue = (status, _, __) => Right(reviewPage(
          status == ReviewStatusFilter.pending
              ? [reviewItem(id: 'a')]
              : [
                  reviewItem(
                    id: 'z',
                    name: 'Marta Solís',
                    status: status == ReviewStatusFilter.approved
                        ? ServiceCredentialStatus.approved
                        : ServiceCredentialStatus.rejected,
                  ),
                ],
          counts: const ReviewCounts(pending: 1, approved: 8, rejected: 4),
        ));
    await open(tester);

    await tester.tap(find.text('Aprobadas'));
    await tester.pumpAndSettle();
    expect(repo.queueRequests.last.status, ReviewStatusFilter.approved);
    expect(find.text('Marta Solís'), findsOneWidget);
    // Decided rows carry their status pill and review date.
    expect(find.text('Aprobada'), findsOneWidget);
    expect(find.textContaining('Revisada el'), findsOneWidget);

    await tester.tap(find.text('Rechazadas'));
    await tester.pumpAndSettle();
    expect(repo.queueRequests.last.status, ReviewStatusFilter.rejected);
    expect(find.text('Rechazada'), findsOneWidget);
  });

  testWidgets('each empty tab has its own message', (tester) async {
    await open(tester);
    await tester.tap(find.text('Aprobadas'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no has aprobado constancias.'), findsOneWidget);
    await tester.tap(find.text('Rechazadas'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no has rechazado constancias.'), findsOneWidget);
  });

  testWidgets('searching sends the term after the debounce', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'laura');
    await tester.pump(kServiceCredentialSearchDebounce);
    await tester.pumpAndSettle();
    expect(repo.queueRequests.last.search, 'laura');

    // No results use the search-specific copy.
    expect(find.text('Sin resultados'), findsOneWidget);
  });

  testWidgets('error state offers retry and recovers', (tester) async {
    repo.queue = (_, __, ___) => const Left(ServerFailure(message: 'x'));
    await open(tester);
    expect(find.byType(SacErrorState), findsOneWidget);
    expect(find.text('No pudimos cargar las constancias'), findsOneWidget);

    repo.queue = (_, __, ___) => Right(reviewPage([reviewItem()]));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Laura Méndez'), findsOneWidget);
  });

  testWidgets('tapping a row opens its detail', (tester) async {
    repo.queue = (_, __, ___) => Right(reviewPage([reviewItem(id: 'abc')]));
    await open(tester);
    await tester.tap(find.text('Laura Méndez'));
    await tester.pumpAndSettle();
    expect(find.text('detail:abc'), findsOneWidget);
  });

  testWidgets('a failed next page shows retry without dropping the list',
      (tester) async {
    repo.queue = (_, __, page) => page == 1
        ? Right(reviewPage(
            [
              for (var i = 0; i < 12; i++)
                reviewItem(id: 'r$i', name: 'Persona $i')
            ],
            total: 30,
            limit: 12,
          ))
        : const Left(ServerFailure(message: 'x'));
    await open(tester, size: const Size(400, 600));

    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(repo.queueRequests.last.page, 2);
    expect(find.text('Persona 0', skipOffstage: false), findsOneWidget);
    expect(find.text('No se pudieron cargar más constancias.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
