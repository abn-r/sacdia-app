import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/members/domain/entities/annual_continuation.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/annual_continuations_view.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../members_test_support.dart';

const _ana = AnnualContinuation(
  userId: 'ana-1',
  name: 'Ana Ruiz',
  baseSectionId: 12,
  ecclesiasticalYearId: 1,
  ecclesiasticalYearName: '2026',
  annualStatus: 'not_enrolled',
  currentRole: 'deputy-director',
  eligibility: 'eligible',
  suggestedClass: SuggestedClass(status: 'resolved', classId: 201),
);

const _luis = AnnualContinuation(
  userId: 'luis-1',
  name: 'Luis Soto',
  baseSectionId: 12,
  ecclesiasticalYearId: 1,
  ecclesiasticalYearName: '2026',
  annualStatus: 'not_enrolled',
  eligibility: 'eligible',
);

const _mia = AnnualContinuation(
  userId: 'mia-1',
  name: 'Mia Menor',
  baseSectionId: 12,
  ecclesiasticalYearId: 1,
  ecclesiasticalYearName: '2026',
  annualStatus: 'not_enrolled',
  eligibility: 'blocked',
  blockedReason: 'MR_CONSENT_NOT_VERIFIED',
);

class _Fake extends AnnualContinuationsNotifier {
  _Fake(this._initial);

  final AnnualContinuationsState _initial;

  @override
  Future<AnnualContinuationsState> build() async => _initial;
}

const _amigo = ProgressiveClass(
  id: 201,
  name: 'Amigo',
  clubTypeId: 2,
  assetCode: 'CQ-01',
);

Future<void> _pump(
  WidgetTester tester, {
  Set<String> selected = const {},
  List<AnnualContinuation> items = const [_ana, _luis, _mia],
  ThemeData? theme,
}) {
  return pumpMembersApp(
    tester,
    theme: theme,
    overrides: [
      annualContinuationsNotifierProvider.overrideWith(
        () => _Fake(
          AnnualContinuationsState(items: items, selectedIds: selected),
        ),
      ),
      allClassesProvider.overrideWith((ref) async => const [_amigo]),
    ],
    // Like the Members tab: its own app bar above the body.
    home: Scaffold(
      appBar: AppBar(),
      body: const AnnualContinuationsBody(),
    ),
  ).then((_) => tester.pumpAndSettle());
}

Finder _submitButton() => find.widgetWithText(SacButton, 'Inscribir para 2026');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  testWidgets('renders both groups with counts, role and suggested class',
      (tester) async {
    await _pump(tester);

    expect(find.text('Listos para inscribir · 2'), findsOneWidget);
    expect(find.text('No se pueden inscribir · 1'), findsOneWidget);
    // Next to the class the role goes without the «Cargo actual:» label.
    expect(
        find.textContaining('Subdirector · Clase sugerida:'), findsOneWidget);
    expect(find.textContaining('Clase sugerida:'), findsOneWidget);
    expect(find.textContaining('Amigo'), findsOneWidget);
    expect(find.text('No elegible'), findsOneWidget);
  });

  testWidgets('hides the blocked group when nobody is blocked', (tester) async {
    await _pump(tester, items: const [_ana, _luis]);

    expect(find.text('Listos para inscribir · 2'), findsOneWidget);
    expect(find.textContaining('No se pueden inscribir'), findsNothing);
  });

  testWidgets('blocked group shows the reason and has no checkbox',
      (tester) async {
    await _pump(tester, items: const [_mia]);

    expect(find.textContaining('consentimiento del tutor'), findsOneWidget);
    expect(find.textContaining('MR_CONSENT_NOT_VERIFIED'), findsNothing);
    expect(find.byKey(const ValueKey('continuation-checkbox-mia-1')),
        findsNothing);
    expect(find.text('Seleccionar todos'), findsNothing);

    // Not tappable, and with nobody eligible there is no enroll bar at all.
    await tester.tap(find.text('Mia Menor'));
    await tester.pump();
    expect(find.text('Selecciona al menos uno'), findsNothing);
    expect(find.textContaining('Inscribir'), findsNothing);
  });

  testWidgets('tapping a row toggles selection and updates the helper',
      (tester) async {
    await _pump(tester);

    expect(find.text('Selecciona al menos uno'), findsOneWidget);

    await tester.tap(find.text('Ana Ruiz'));
    await tester.pumpAndSettle();
    expect(find.text('1 seleccionado de 2'), findsOneWidget);

    await tester.tap(find.text('Luis Soto'));
    await tester.pumpAndSettle();
    expect(find.text('2 seleccionados de 2'), findsOneWidget);

    await tester.tap(find.text('Ana Ruiz'));
    await tester.pumpAndSettle();
    expect(find.text('1 seleccionado de 2'), findsOneWidget);
  });

  testWidgets('row exposes checkbox semantics with its checked state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: {'ana-1'});

    expect(
      tester.getSemantics(find.byKey(const ValueKey('continuation-ana-1'))),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    handle.dispose();
  });

  testWidgets('«Seleccionar todos» / «Quitar todos» toggle every eligible item',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Seleccionar todos'));
    await tester.pumpAndSettle();
    expect(find.text('2 seleccionados de 2'), findsOneWidget);
    expect(find.text('Quitar todos'), findsOneWidget);
    expect(find.text('Seleccionar todos'), findsNothing);

    await tester.tap(find.text('Quitar todos'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona al menos uno'), findsOneWidget);
    expect(find.text('Seleccionar todos'), findsOneWidget);
  });

  testWidgets('submit button is disabled with 0 selected, enabled otherwise',
      (tester) async {
    await _pump(tester);

    expect(tester.widget<SacButton>(_submitButton()).isEnabled, isFalse);

    await tester.tap(find.text('Ana Ruiz'));
    await tester.pumpAndSettle();
    expect(tester.widget<SacButton>(_submitButton()).isEnabled, isTrue);
  });

  testWidgets(
      'regression: the first group sits right under the hint, no top-bar gap',
      (tester) async {
    await _pump(tester);

    final hint = tester.getRect(find.textContaining('Elige a quién inscribir'));
    final header = tester.getRect(find.text('Listos para inscribir · 2'));

    expect(header.top - hint.bottom, lessThan(48));
    expect(header.top, greaterThan(hint.bottom));

    // The hint itself also starts right below the app bar (embedded case).
    final bar = tester.getRect(find.byType(AppBar));
    expect(hint.top - bar.bottom, lessThan(48));
  });

  testWidgets('standalone view keeps the list below its frosted top bar',
      (tester) async {
    await pumpMembersApp(
      tester,
      overrides: [
        annualContinuationsNotifierProvider.overrideWith(
          () => _Fake(
            const AnnualContinuationsState(items: [_ana, _luis, _mia]),
          ),
        ),
        allClassesProvider.overrideWith((ref) async => const [_amigo]),
      ],
      home: const AnnualContinuationsView(),
    );
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(SacTopBar));
    final hint = tester.getRect(find.textContaining('Elige a quién inscribir'));
    expect(hint.top, greaterThanOrEqualTo(bar.bottom - 1));
  });

  testWidgets('a light accent gives the button and checkbox dark ink',
      (tester) async {
    final bees = SacAccent.byId('class.busy_bees');
    await _pump(
      tester,
      selected: {'ana-1'},
      theme: AppTheme.buildLight(bees),
    );

    // Sanity: this accent really is light (dark ink, not white).
    expect(bees.onColor, isNot(Colors.white));

    final label = tester.widget<Text>(find.text('Inscribir para 2026'));
    expect(label.style?.color, bees.onColor);

    final checkbox = find.byKey(const ValueKey('continuation-checkbox-ana-1'));
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: checkbox,
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((box.decoration! as BoxDecoration).color, bees.color);
    final tick = tester.widget<HugeIcon>(
      find.descendant(of: checkbox, matching: find.byType(HugeIcon)),
    );
    expect(tick.color, bees.onColor);
  });

  test('selectAll never selects blocked items; clearAll empties', () async {
    final container = createTestContainer(overrides: [
      annualContinuationsNotifierProvider.overrideWith(
        () => _Fake(
          const AnnualContinuationsState(items: [_ana, _luis, _mia]),
        ),
      ),
    ]);
    final notifier =
        container.read(annualContinuationsNotifierProvider.notifier);
    await container.read(annualContinuationsNotifierProvider.future);

    notifier.selectAll();
    expect(
        container.read(annualContinuationsNotifierProvider).value!.selectedIds,
        {'ana-1', 'luis-1'});

    notifier.clearAll();
    expect(
        container.read(annualContinuationsNotifierProvider).value!.selectedIds,
        isEmpty);
  });
}
