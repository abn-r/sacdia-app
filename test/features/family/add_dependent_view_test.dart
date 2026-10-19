import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/family/presentation/views/add_dependent_view.dart';

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

  Future<void> pump(WidgetTester tester) async {
    await pumpFamilyApp(
      tester,
      overrides: familyOverrides(repo: repo, auth: auth),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const AddDependentView()),
      ],
    );
    // Tall surface so the whole form is on screen.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester, {bool pickDate = true}) async {
    // Order of the form: name, paternal, maternal.
    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(1), 'Pérez');
    await tester.enterText(find.byType(TextFormField).at(2), 'López');
    if (pickDate) {
      await tester.tap(find.text('Selecciona la fecha'));
      await tester.pumpAndSettle();
      final ok = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).okButtonLabel;
      await tester.tap(find.text(ok));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Madre').last);
    await tester.pumpAndSettle();
  }

  SacButton submitButton(WidgetTester tester) => tester.widget<SacButton>(
      find.widgetWithText(SacButton, 'Registrar y continuar'));

  testWidgets(
      'submit stays disabled until sworn declaration AND legal are '
      'ticked', (tester) async {
    await pump(tester);
    await fillForm(tester);

    expect(submitButton(tester).onPressed, isNull);

    await tester.tap(find.byType(Checkbox).first); // sworn
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNull, reason: 'legal pending');

    await tester.tap(find.byType(Checkbox).last); // terms + privacy
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'submits the contract with the legal versions the user saw and '
      'then switches to the new dependent', (tester) async {
    await pump(tester);
    await fillForm(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar y continuar'));
    await tester.pumpAndSettle();

    final input = repo.createInputs.single;
    expect(input.name, 'Ana');
    expect(input.paternalLastName, 'Pérez');
    expect(input.maternalLastName, 'López');
    expect(input.relationshipTypeId, 'rel-1');
    expect(input.swornDeclaration, isTrue);
    expect(input.acceptedTermsVersion, '1.0.0-store');
    expect(input.acceptedPrivacyVersion, '1.0.1-store');
    expect(input.birthday, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(auth.switchCalls, [(id: 'ana-1', firstName: 'Ana')]);
  });

  testWidgets(
      'the relationship picker lists only the guardianship types, labelled '
      'from the guardian point of view', (tester) async {
    await pump(tester);

    expect(find.text('Tu parentesco con el menor'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Madre'), findsWidgets);
    expect(find.text('Padre'), findsWidgets);
    expect(find.text('Primo'), findsNothing,
        reason: 'the full /catalogs list must not reach the family picker');
  });

  testWidgets('relationship type not allowed shows the translated message',
      (tester) async {
    repo.created = const Left(
      ServerFailure(
        message: 'x',
        code: 422,
        errorCode: 'GUARDIANSHIP_RELATIONSHIP_TYPE_NOT_ALLOWED',
      ),
    );
    await pump(tester);
    await fillForm(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar y continuar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ese parentesco no está permitido para un tutor'),
      findsOneWidget,
    );
    expect(auth.switchCalls, isEmpty);
  });

  testWidgets('age out of range shows the translated message and stays',
      (tester) async {
    repo.created = const Left(
      ServerFailure(
        message: 'x',
        code: 422,
        errorCode: 'GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE',
      ),
    );
    await pump(tester);
    await fillForm(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar y continuar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Solo puedes registrar a menores de 13 años'),
      findsOneWidget,
    );
    expect(auth.switchCalls, isEmpty);
    expect(find.byType(AddDependentView), findsOneWidget);
  });

  testWidgets(
      'guardian not adult shows the message and a complete-profile '
      'action', (tester) async {
    repo.created = const Left(
      ServerFailure(
        message: 'x',
        code: 422,
        errorCode: 'GUARDIANSHIP_GUARDIAN_NOT_ADULT',
      ),
    );
    await pump(tester);
    await fillForm(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar y continuar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Debes ser mayor de edad'), findsOneWidget);
    expect(find.text('Completar mi perfil'), findsOneWidget);
  });

  testWidgets('missing guardian birthday shows its own message',
      (tester) async {
    repo.created = const Left(
      ServerFailure(
        message: 'x',
        code: 422,
        errorCode: 'GUARDIANSHIP_GUARDIAN_BIRTHDAY_REQUIRED',
      ),
    );
    await pump(tester);
    await fillForm(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar y continuar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Completa tu fecha de nacimiento'),
      findsOneWidget,
    );
    expect(find.text('Completar mi perfil'), findsOneWidget);
  });

  testWidgets(
      'LEGAL_VERSION_MISMATCH reloads the documents and asks to '
      'accept again', (tester) async {
    repo.created = const Left(
      ServerFailure(
        message: 'x',
        code: 400,
        errorCode: 'LEGAL_VERSION_MISMATCH',
      ),
    );
    await pump(tester);
    await fillForm(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar y continuar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Los términos cambiaron. Léelos y acepta de nuevo.'),
      findsOneWidget,
    );
    // The legal consent was reset: submit is disabled again.
    expect(submitButton(tester).onPressed, isNull);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isFalse);
  });

  testWidgets('dependent limit shows its message', (tester) async {
    repo.created = const Left(
      ServerFailure(
        message: 'x',
        code: 409,
        errorCode: 'GUARDIANSHIP_DEPENDENT_LIMIT_REACHED',
      ),
    );
    await pump(tester);
    await fillForm(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar y continuar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Alcanzaste el máximo de menores'),
      findsOneWidget,
    );
  });

  testWidgets('the legal consent says it is on behalf of the minor',
      (tester) async {
    await pump(tester);

    expect(find.textContaining('Acepto en nombre del menor'), findsOneWidget);
  });

  testWidgets('without legal documents the form cannot be submitted',
      (tester) async {
    await pumpFamilyApp(
      tester,
      overrides: familyOverrides(repo: repo, auth: auth, legal: const []),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const AddDependentView()),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudieron cargar los documentos legales.'),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
  });
}
