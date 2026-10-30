import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/models/allergy_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/allergies_selection_view.dart';

import '../family/family_test_harness.dart';

/// `userAllergiesProvider` con un resultado fijo. `refresh()` (que la vista
/// dispara en `initState`) no hace nada para no pisar el estado fijado.
class _FixedAllergies extends UserAllergiesNotifier {
  _FixedAllergies(this._result);

  final Future<List<AllergyModel>> Function() _result;

  @override
  Future<List<AllergyModel>> build() => _result();

  @override
  Future<void> refresh() async {}

  /// Fuerza el paso a error de forma sincrona, en la zona del llamador.
  void fail(Object error) => state = AsyncError(error, StackTrace.current);
}

/// `selectedAllergiesProvider` es autoDispose y nadie lo observa: sin esto, lo
/// que escribe el listener de la vista se descarta antes de poder leerlo.
final _keepSelected = selectedAllergiesProvider.overrideWith((ref) {
  ref.keepAlive();
  return <int>[];
});

const _catalog = [
  AllergyModel(id: 1, name: 'Polen'),
  AllergyModel(id: 2, name: 'Nueces'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Future<List<AllergyModel>> Function() userAllergies, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => FakeAuthNotifier(guardianUser)),
        allergiesCatalogProvider.overrideWith((ref) async => _catalog),
        userAllergiesProvider
            .overrideWith(() => _FixedAllergies(userAllergies)),
        healthNoneStateProvider.overrideWith(() => _NoneState()),
        _keepSelected,
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const AllergiesSelectionView(),
        ),
      ],
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return ProviderScope.containerOf(
      tester.element(find.byType(AllergiesSelectionView)),
    );
  }

  // S4.1 (riverpod-3-migration): with the user's allergies in AsyncError and no
  // previous value, the listener must NOT seed anything (the error is never
  // swallowed as an empty list) and the failure keeps reaching the global
  // error handler, exactly as with Riverpod 2.6 (`.value` rethrew there).
  //
  // The error is forced synchronously inside `runZonedGuarded`: Riverpod runs
  // listeners with `Zone.current.runBinaryGuarded`, so a throwing listener
  // lands in that zone's uncaught-error handler (in the app: Sentry).
  testWidgets(
      'S4.1: allergies in AsyncError with no prior value seed nothing and '
      'surface the error', (tester) async {
    final never = Completer<List<AllergyModel>>();
    final container = await pump(tester, () => never.future, settle: false);
    expect(container.read(userAllergiesProvider).isLoading, isTrue);

    final uncaught = <Object>[];
    runZonedGuarded(
      () => (container.read(userAllergiesProvider.notifier) as _FixedAllergies)
          .fail(StateError('allergies-load-failed')),
      (error, _) => uncaught.add(error),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(userAllergiesProvider).hasError, isTrue);
    expect(container.read(userAllergiesProvider).hasValue, isFalse);
    expect(uncaught, hasLength(1));
    expect(uncaught.single, isA<StateError>());
    expect((uncaught.single as StateError).message, 'allergies-load-failed');
    expect(container.read(selectedAllergiesProvider), isEmpty);
    // The catalog still renders: a failed user lookup does not blank the view.
    expect(find.text('Polen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('control: loaded user allergies are seeded exactly once',
      (tester) async {
    final container = await pump(
      tester,
      () async => const [AllergyModel(id: 2, name: 'Nueces')],
    );

    expect(container.read(selectedAllergiesProvider), [2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('control: still loading seeds nothing and throws nothing',
      (tester) async {
    final never = Completer<List<AllergyModel>>();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => FakeAuthNotifier(guardianUser)),
        allergiesCatalogProvider.overrideWith((ref) async => _catalog),
        userAllergiesProvider
            .overrideWith(() => _FixedAllergies(() => never.future)),
        healthNoneStateProvider.overrideWith(() => _NoneState()),
        _keepSelected,
      ],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const AllergiesSelectionView()),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AllergiesSelectionView)),
    );
    expect(container.read(userAllergiesProvider).isLoading, isTrue);
    expect(container.read(selectedAllergiesProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _NoneState extends HealthNoneStateNotifier {
  @override
  Future<HealthNoneState> build() async => const HealthNoneState();
}
