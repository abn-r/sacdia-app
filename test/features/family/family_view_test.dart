import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/views/family_view.dart';
import 'package:sacdia_app/features/family/presentation/widgets/dependent_card.dart';

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

  testWidgets('two dependents render two cards with the right badges',
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

    expect(find.byType(DependentCard), findsNWidgets(2));
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Luis Pérez'), findsOneWidget);
    expect(find.text('Consentimiento pendiente'), findsOneWidget);
    expect(find.text('Consentimiento verificado'), findsOneWidget);
    expect(find.text('9 años'), findsOneWidget);
    expect(find.text('Sin club'), findsNWidgets(2));
    expect(find.text('Añadir menor'), findsOneWidget);
    expect(find.text('Tengo un código de vinculación'), findsOneWidget);
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

    expect(find.text('Solicitud pendiente en Club Águilas'), findsOneWidget);
  });

  testWidgets('a frozen dependent shows the frozen state and no view-as',
      (tester) async {
    repo.overview = Right(
      FamilyOverview(dependents: [summary(frozen: true)], maxDependents: 10),
    );

    await pump(tester);

    expect(find.text('Congelado'), findsOneWidget);
    expect(find.textContaining('Se borrará pasados 90 días'), findsOneWidget);
    expect(find.text('Ver como Ana'), findsNothing);
  });

  testWidgets('empty state invites to add a minor', (tester) async {
    repo.overview =
        const Right(FamilyOverview(dependents: [], maxDependents: 10));

    final router = await pump(tester);

    expect(find.text('Aún no has añadido menores'), findsOneWidget);
    await tester.tap(find.text('Añadir menor'));
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
    await tester.tap(find.text('Añadir menor'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
  });

  testWidgets('"Tengo un código de vinculación" opens the redeem screen',
      (tester) async {
    final router = await pump(tester);
    await tester.scrollUntilVisible(
      find.text('Tengo un código de vinculación'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Tengo un código de vinculación'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/family/link');
  });

  testWidgets('tapping a card opens its detail', (tester) async {
    final router = await pump(tester);

    await tester.tap(find.text('Ana Pérez'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/family/ana-1');
  });

  testWidgets('"Ver como" switches profile with the dependent first name',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Ver como Ana'));
    await tester.pumpAndSettle();

    expect(auth.switchCalls, [(id: 'ana-1', firstName: 'Ana')]);
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
