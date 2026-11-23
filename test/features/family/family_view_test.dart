import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/views/family_view.dart';
import 'package:sacdia_app/features/family/presentation/widgets/family_row.dart';

import 'family_fixtures.dart';
import 'family_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeFamilyRepository repo;
  late FakeAuthNotifier auth;

  setUp(() {
    repo = FakeFamilyRepository();
    auth = FakeAuthNotifier();
  });

  Future<GoRouter> pump(WidgetTester tester) => pumpFamilyApp(
        tester,
        overrides: familyOverrides(repo: repo, auth: auth),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const FamilyView()),
          stubRoute('/family/add'),
          stubRoute('/family/link'),
          stubRoute('/family/:dependentId'),
        ],
      );

  testWidgets('two dependents render as rows with the line that matters',
      (tester) async {
    repo.overview = Right(
      FamilyOverview(
        dependents: [
          summary(),
          summary(id: 'luis-1', name: 'Luis', age: 6, consent: 'verified'),
        ],
        maxDependents: 10,
      ),
    );

    await pump(tester);

    expect(find.byType(DependentRow), findsNWidgets(2));
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Luis Pérez'), findsOneWidget);
    // Ana still misses her signed form; Luis is verified, so only his club.
    expect(find.text('9 años · Falta la ficha firmada · Sin club'),
        findsOneWidget);
    expect(find.text('6 años · Sin club'), findsOneWidget);
    expect(find.text('Registrar a un menor'), findsOneWidget);
    expect(find.text('Tengo un código'), findsOneWidget);
    // "Ver como" lives in the minor's profile, not on every row.
    expect(find.textContaining('Ver como'), findsNothing);
  });

  testWidgets('club status shows on the card', (tester) async {
    repo.overview = Right(
      FamilyOverview(
        dependents: [
          DependentSummary(
            userId: 'ana-1',
            name: 'Ana',
            age: 9,
            guardianship: const DependentGuardianship(
              guardianshipId: 'gs-1',
              isPrimary: true,
              consentStatus: GuardianConsentStatus.pending,
              evidenceUploaded: false,
            ),
            clubMembership: const DependentClubMembership(
              assignmentId: 'a-1',
              status: 'pending',
              clubName: 'Club Águilas',
            ),
          ),
        ],
        maxDependents: 10,
      ),
    );

    await pump(tester);

    expect(
      find.text('9 años · Falta la ficha firmada · '
          'Solicitud pendiente en Club Águilas'),
      findsOneWidget,
    );
  });

  testWidgets('a frozen dependent shows the frozen state and no view-as',
      (tester) async {
    repo.overview = Right(
      FamilyOverview(dependents: [summary(frozen: true)], maxDependents: 10),
    );

    await pump(tester);

    expect(find.text('Congelado · Sin tutor ni club'), findsOneWidget);
    expect(find.text('Ver como Ana'), findsNothing);
    // Nothing to do for a frozen minor: no "missing form" panel.
    expect(find.byKey(const ValueKey('family-missing-form')), findsNothing);
  });

  testWidgets('empty state invites to add a minor', (tester) async {
    repo.overview =
        const Right(FamilyOverview(dependents: [], maxDependents: 10));

    final router = await pump(tester);

    expect(find.text('Acompaña a tus menores'), findsOneWidget);
    await tester.tap(find.text('Registrar a un menor'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/family/add');
    expect(find.text('route:/family/add'), findsOneWidget);
  });

  testWidgets('the add CTA is disabled and explained at the limit',
      (tester) async {
    repo.overview = Right(
      FamilyOverview(
        dependents: List.generate(10, (i) => summary(id: 'd$i', name: 'M$i')),
        maxDependents: 10,
      ),
    );

    final router = await pump(tester);
    await tester.scrollUntilVisible(
      find.text('Alcanzaste el máximo de 10 menores.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Alcanzaste el máximo de 10 menores.'), findsOneWidget);
    await tester.tap(find.text('Registrar a un menor'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
  });

  testWidgets('"Tengo un código de vinculación" opens the redeem screen',
      (tester) async {
    final router = await pump(tester);
    await tester.scrollUntilVisible(
      find.text('Tengo un código'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Tengo un código'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/family/link');
  });

  testWidgets('tapping a card opens its detail', (tester) async {
    final router = await pump(tester);

    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/family/ana-1');
  });

  testWidgets('a missing signed form is the first thing, and opens the minor',
      (tester) async {
    repo.overview = Right(
      FamilyOverview(
        dependents: [
          summary(id: 'luis-1', name: 'Luis', age: 6, consent: 'verified'),
          summary(),
        ],
        maxDependents: 10,
      ),
    );
    final router = await pump(tester);

    expect(find.byKey(const ValueKey('family-missing-form')), findsOneWidget);
    expect(find.text('Falta la ficha de Ana'), findsOneWidget);
    await tester.tap(find.text('Falta la ficha de Ana'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/family/ana-1');
  });

  testWidgets('several missing forms are counted', (tester) async {
    repo.overview = Right(
      FamilyOverview(
        dependents: [summary(), summary(id: 'luis-1', name: 'Luis')],
        maxDependents: 10,
      ),
    );
    await pump(tester);

    expect(find.text('Faltan 2 fichas firmadas'), findsOneWidget);
  });

  testWidgets('a load error shows a translated message and retries',
      (tester) async {
    repo.overview = const Left(
      ServerFailure(message: 'boom', code: 500),
    );

    await pump(tester);

    expect(find.text('Algo salió mal. Intenta de nuevo.'), findsOneWidget);

    repo.overview = Right(
      FamilyOverview(dependents: [summary()], maxDependents: 10),
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(repo.listCalls, greaterThanOrEqualTo(2));
  });
}
