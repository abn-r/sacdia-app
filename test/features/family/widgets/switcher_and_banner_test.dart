import 'package:dartz/dartz.dart' show Right;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/acting_providers.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/widgets/acting_for_banner.dart';
import 'package:sacdia_app/features/family/presentation/widgets/family_profile_entry.dart';
import 'package:sacdia_app/features/family/presentation/widgets/profile_switcher_sheet.dart';

import '../family_fixtures.dart';
import '../family_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeFamilyRepository repo;
  late FakeAuthNotifier auth;
  late ProviderContainer container;

  setUp(() {
    repo = FakeFamilyRepository();
    auth = FakeAuthNotifier();
    repo.overview = Right(
      FamilyOverview(
        dependents: [
          summary(),
          summary(id: 'luis-1', name: 'Luis', age: 6, consent: 'verified'),
          summary(id: 'eva-1', name: 'Eva', frozen: true),
        ],
        maxDependents: 10,
      ),
    );
  });

  /// Monta [body] dentro del árbol real de providers para poder abrir la hoja.
  Future<void> pump(
    WidgetTester tester, {
    required Widget body,
    List<GoRoute> extra = const [],
  }) async {
    await pumpFamilyApp(
      tester,
      overrides: familyOverrides(repo: repo, auth: auth),
      routes: [
        GoRoute(path: '/', builder: (_, __) => Scaffold(body: body)),
        ...extra,
      ],
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  Widget opener() => Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => showProfileSwitcherSheet(context),
          child: const Text('open'),
        ),
      );

  group('profile switcher (FP-63)', () {
    testWidgets('lists You + non-frozen dependents, never a frozen one',
        (tester) async {
      await pump(tester, body: opener());

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar de perfil'), findsOneWidget);
      expect(find.text('Tú'), findsOneWidget);
      expect(find.text('María'), findsOneWidget); // the guardian's own name
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);
      expect(find.text('Eva'), findsNothing);
      expect(find.text('Consentimiento pendiente'), findsOneWidget);
      expect(find.text('Consentimiento verificado'), findsOneWidget);
    });

    testWidgets('selecting a dependent calls switchProfile with its name',
        (tester) async {
      await pump(tester, body: opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Luis'));
      await tester.pumpAndSettle();

      expect(auth.switchCalls, [(id: 'luis-1', firstName: 'Luis')]);
      expect(find.text('Cambiar de perfil'), findsNothing, reason: 'closed');
    });

    testWidgets('while acting, You is tappable and the acted one is marked',
        (tester) async {
      await pump(tester, body: opener());
      container
          .read(actingForSessionProvider)
          .enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      container.read(guardianUserProvider.notifier).state = guardianUser;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Ana is the current profile: tapping her does nothing.
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      expect(auth.switchCalls, isEmpty);

      await tester.tap(find.text('Tú'));
      await tester.pumpAndSettle();
      expect(auth.switchCalls, [(id: null, firstName: null)]);
    });

    testWidgets('an offline switch is explained', (tester) async {
      auth.outcome = SwitchProfileOutcome.offline;
      await pump(tester, body: opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión. Volviste a tu perfil.'), findsOneWidget);
    });

    testWidgets('no dependents shows the empty hint', (tester) async {
      repo.overview =
          const Right(FamilyOverview(dependents: [], maxDependents: 10));
      await pump(tester, body: opener());

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes menores a los que puedas cambiar.'),
        findsOneWidget,
      );
    });
  });

  group('acting banner (FP-63)', () {
    testWidgets('shows the first name and returns to the guardian on tap',
        (tester) async {
      await pump(
        tester,
        body: ActingForBanner(
          dependent: const ActingDependent(userId: 'ana-1', firstName: 'Ana'),
          topInset: 0,
          onBack: () => auth.switchProfile(null),
        ),
      );

      expect(find.textContaining('Viendo como Ana'), findsOneWidget);
      expect(find.textContaining('Volver a mi perfil'), findsOneWidget);

      await tester.tap(find.byType(ActingForBanner));
      await tester.pump();
      expect(auth.switchCalls, [(id: null, firstName: null)]);
    });

    testWidgets('the host only shows the banner while acting', (tester) async {
      await pump(
        tester,
        body: const ActingForBannerHost(child: Text('app content')),
      );
      // The host is used inside a Scaffold here; the banner starts hidden.
      expect(find.byType(ActingForBanner), findsNothing);
      expect(find.text('app content'), findsOneWidget);

      container
          .read(actingForSessionProvider)
          .enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      await tester.pumpAndSettle();
      expect(find.byType(ActingForBanner), findsOneWidget);
      expect(find.textContaining('Viendo como Ana'), findsOneWidget);
      expect(find.text('app content'), findsOneWidget);

      container.read(actingForSessionProvider).exit();
      await tester.pumpAndSettle();
      expect(find.byType(ActingForBanner), findsNothing);
    });

    testWidgets('the child keeps its state across entering and leaving',
        (tester) async {
      await pump(tester, body: const ActingForBannerHost(child: _Counter()));
      await tester.tap(find.text('count 0'));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);

      container
          .read(actingForSessionProvider)
          .enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      await tester.pumpAndSettle();
      expect(find.text('count 1'), findsOneWidget, reason: 'not rebuilt');

      container.read(actingForSessionProvider).exit();
      await tester.pumpAndSettle();
      expect(find.text('count 1'), findsOneWidget);
    });
  });

  group('profile entry (FP-57)', () {
    testWidgets(
        'shows Mi familia for a guardian with dependents and the '
        'switcher entry', (tester) async {
      auth.user = const UserEntity(
        id: 'guardian-1',
        name: 'María',
        postRegisterComplete: true,
        family: FamilySummary(isGuardian: true, dependentsCount: 2),
      );
      await pump(
        tester,
        body: const FamilyProfileEntry(horizontalPadding: 16),
      );

      expect(find.text('Mi familia'), findsOneWidget);
      expect(find.text('2 menores a tu cargo'), findsOneWidget);
      expect(find.text('Cambiar de perfil'), findsOneWidget);
    });

    testWidgets('with no dependents only Mi familia is offered',
        (tester) async {
      auth.user = const UserEntity(
        id: 'guardian-1',
        name: 'María',
        postRegisterComplete: true,
        family: FamilySummary(isGuardian: false, dependentsCount: 0),
      );
      await pump(
        tester,
        body: const FamilyProfileEntry(horizontalPadding: 16),
      );

      expect(find.text('Mi familia'), findsOneWidget);
      expect(find.text('Cambiar de perfil'), findsNothing);
    });

    testWidgets('is hidden for a supervised teen (no Mi familia, no switcher)',
        (tester) async {
      auth.user = const UserEntity(
        id: 'teen-1',
        name: 'Ana',
        postRegisterComplete: true,
        serverMode: AccountMode.teenSupervised,
        family: FamilySummary(isGuardian: true, dependentsCount: 2),
      );
      await pump(
        tester,
        body: const FamilyProfileEntry(horizontalPadding: 16),
      );

      expect(find.text('Mi familia'), findsNothing);
      expect(find.text('Cambiar de perfil'), findsNothing);
    });

    testWidgets('is hidden while acting for a dependent', (tester) async {
      await pump(
        tester,
        body: const FamilyProfileEntry(horizontalPadding: 16),
      );
      expect(find.text('Mi familia'), findsOneWidget);

      container
          .read(actingForSessionProvider)
          .enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      await tester.pumpAndSettle();

      expect(find.text('Mi familia'), findsNothing);
      expect(find.text('Cambiar de perfil'), findsNothing);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => _count++),
        child: Text('count $_count'),
      );
}
