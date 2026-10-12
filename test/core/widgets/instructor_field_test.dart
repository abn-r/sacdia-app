import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/instructor_field.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_picker_field.dart';

import '../../features/certificate_import/support/test_app.dart';
import '../../support/instructor_fakes.dart';

Future<List<InstructorSelection>> _show(
  WidgetTester tester,
  InstructorSelection selection, {
  String? errorText,
  FakeInstructorSearch? search,
}) async {
  phoneSurface(tester);
  final changes = <InstructorSelection>[];
  await tester.pumpWidget(wrapTestApp(
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: InstructorField(
          selection: selection,
          errorText: errorText,
          onChanged: changes.add,
        ),
      ),
    ),
    overrides: [(search ?? FakeInstructorSearch()).override],
  ));
  await tester.pumpAndSettle();
  return changes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  testWidgets('empty: invites to add one, says it is optional and who is told',
      (tester) async {
    await _show(tester, const InstructorSelection.none());

    expect(find.text('Instructor o instructora'), findsOneWidget);
    expect(find.text('Agregar instructor (opcional)'), findsOneWidget);
    expect(
        find.text('Tu Campo Local revisa este dato. No avisamos a la persona.'),
        findsOneWidget);
    expect(find.widgetWithText(SacButton, 'Quitar'), findsNothing);
  });

  testWidgets('a person of the Local Field shows initials and the scope',
      (tester) async {
    await _show(tester, anaGomez);

    expect(find.text('Ana Gómez'), findsOneWidget);
    expect(find.text('Persona de tu Campo Local'), findsOneWidget);
    expect(find.text('AG'), findsOneWidget);
    expect(find.text('Nombre escrito · no verificado'), findsNothing);
    expect(
      tester.getSemantics(find.text('Ana Gómez')),
      matchesSemantics(
        label: 'Instructor: Ana Gómez, persona de tu Campo Local',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
  });

  testWidgets('a typed name is flagged as not verified', (tester) async {
    await _show(tester, const InstructorSelection.external('Juan López'));

    expect(find.text('Juan López'), findsOneWidget);
    expect(find.text('Nombre escrito · no verificado'), findsOneWidget);
    expect(find.text('Persona de tu Campo Local'), findsNothing);
  });

  testWidgets('"Quitar" empties the choice and is at least 48 px tall',
      (tester) async {
    final changes = await _show(tester, anaGomez);

    final remove = find.widgetWithText(SacButton, 'Quitar');
    expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect(changes.single.isNone, isTrue);
  });

  testWidgets('tapping the field opens the picker and reports the choice',
      (tester) async {
    final changes = await _show(tester, const InstructorSelection.none());

    await tester.tap(find.text('Agregar instructor (opcional)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Gómez'));
    await tester.pumpAndSettle();

    expect(changes.single, anaGomez);
  });

  testWidgets('dismissing the picker changes nothing', (tester) async {
    final changes = await _show(tester, anaGomez);

    await tester.tap(find.text('Ana Gómez'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  testWidgets('shows the error on the field', (tester) async {
    await _show(
      tester,
      anaGomez,
      errorText:
          'Esta persona no está disponible. Elige a otra o escribe su nombre',
    );

    expect(
      find.text(
          'Esta persona no está disponible. Elige a otra o escribe su nombre'),
      findsOneWidget,
    );
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'empty to filled crossfades${reduced ? ' without scale (Reduced Motion)' : ' with a small scale'}',
        (tester) async {
      if (reduced) reduceMotion(tester);
      Widget field(InstructorSelection selection) => wrapTestApp(
            Scaffold(
              body: InstructorField(selection: selection, onChanged: (_) {}),
            ),
            overrides: [FakeInstructorSearch().override],
          );
      phoneSurface(tester);
      await tester.pumpWidget(field(const InstructorSelection.none()));
      await tester.pumpAndSettle();

      await tester.pumpWidget(field(anaGomez));
      await tester.pump(const Duration(milliseconds: 60));

      final scales = find.descendant(
        of: find.byType(SacPickerField),
        matching: find.byType(ScaleTransition),
      );
      expect(scales, reduced ? findsNothing : findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('Ana Gómez'), findsOneWidget);
    });
  }
}
