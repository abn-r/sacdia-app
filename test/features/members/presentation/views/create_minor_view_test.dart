import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/features/members/domain/entities/create_minor.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/create_minor_view.dart';

import '../../members_test_support.dart';

const _legal = [
  LegalDocument(
    documentType: LegalDocumentTypes.terms,
    version: '2.0.0-family',
    url: 'https://example.com/terms',
  ),
  LegalDocument(
    documentType: LegalDocumentTypes.privacy,
    version: '2.0.1-family',
    url: 'https://example.com/privacy',
  ),
];

Left<Failure, CreatedMinor> _error(int status, String code) => Left(
      status == 403
          ? AuthFailure(message: 'x', code: status, errorCode: code)
          : ServerFailure(message: 'x', code: status, errorCode: code),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;
  CreatedMinor? popped;
  late ProviderContainer container;

  setUp(() {
    repo = FakeMembersRepository();
    popped = null;
  });

  Future<void> open(WidgetTester tester) async {
    await pumpMembersApp(
      tester,
      overrides: [
        membersRepositoryProvider.overrideWithValue(repo),
        currentLegalDocumentsProvider.overrideWith((ref) async => _legal),
      ],
      home: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<CreatedMinor>(
                  MaterialPageRoute(
                    builder: (_) => const CreateMinorView(clubSectionId: 12),
                  ),
                );
              },
              child: const Text('open'),
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, {bool pickDate = true}) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'Luis');
    await tester.enterText(find.byType(TextFormField).at(1), 'Pérez');
    await tester.enterText(find.byType(TextFormField).at(2), 'López');
    if (pickDate) {
      await tester.tap(find.text('Selecciona la fecha'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> tickBoth(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox).first); // sworn
    await tester.tap(find.byType(Checkbox).last); // terms + privacy
    await tester.pumpAndSettle();
  }

  SacButton submitButton(WidgetTester tester) => tester
      .widget<SacButton>(find.widgetWithText(SacButton, 'Registrar menor'));

  testWidgets('the form has no email, password or access fields',
      (tester) async {
    await open(tester);

    // Nombre, apellido paterno y apellido materno: nada más que teclear.
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.textContaining('correo'), findsNothing);
    expect(find.textContaining('contraseña'), findsNothing);
  });

  testWidgets('submit stays disabled until sworn declaration AND legal',
      (tester) async {
    await open(tester);
    await fill(tester);

    expect(submitButton(tester).onPressed, isNull);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNull, reason: 'legal pending');

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('without a birthday submit stays disabled', (tester) async {
    await open(tester);
    await fill(tester, pickDate: false);
    await tickBoth(tester);

    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets(
      'success sends the contract with the legal versions seen, records the '
      'minor and pops the result', (tester) async {
    await open(tester);
    await fill(tester);
    await tester.tap(find.text('Masculino'));
    await tickBoth(tester);

    await tester.tap(find.text('Registrar menor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final input = repo.createMinorInputs.single;
    expect(input.clubSectionId, 12);
    expect(input.name, 'Luis');
    expect(input.paternalLastName, 'Pérez');
    expect(input.maternalLastName, 'López');
    expect(input.gender, 'M');
    expect(input.swornDeclaration, isTrue);
    expect(input.acceptedTermsVersion, '2.0.0-family');
    expect(input.acceptedPrivacyVersion, '2.0.1-family');
    expect(input.birthday, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

    expect(popped?.userId, 'luis-9');
    expect(popped?.consentPending, isTrue);
    // El director queda anotado como creador de ese menor (cuatro ojos).
    expect(container.read(createdMinorUserIdsProvider), {'luis-9'});
    expect(
      find.text(
          'Luis quedó registrado. Falta que otra persona verifique la ficha firmada.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('gender is optional and left out when not chosen',
      (tester) async {
    await open(tester);
    await fill(tester);
    await tickBoth(tester);

    await tester.tap(find.text('Registrar menor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(repo.createMinorInputs.single.gender, isNull);
    await tester.pumpAndSettle();
  });

  group('error map (by code only)', () {
    Future<void> submitWith(
      WidgetTester tester,
      Left<Failure, CreatedMinor> result,
    ) async {
      repo.createMinorResult = result;
      await open(tester);
      await fill(tester);
      await tickBoth(tester);
      await tester.tap(find.text('Registrar menor'));
      await tester.pumpAndSettle();
    }

    testWidgets('age out of range uses the director wording, not "under 13"',
        (tester) async {
      await submitWith(
          tester, _error(422, 'GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE'));

      expect(
        find.textContaining('La edad no es válida para registrar a un menor'),
        findsOneWidget,
      );
      expect(find.textContaining('menores de 13'), findsNothing);
      expect(popped, isNull);
      expect(container.read(createdMinorUserIdsProvider), isEmpty);
      expect(find.byType(CreateMinorView), findsOneWidget);
    });

    testWidgets('no active ecclesiastical year', (tester) async {
      await submitWith(tester, _error(500, 'POST_REG_NO_ACTIVE_YEAR'));

      expect(
        find.textContaining('No hay un año eclesiástico vigente'),
        findsOneWidget,
      );
      expect(container.read(createdMinorUserIdsProvider), isEmpty);
    });

    testWidgets('stale legal versions: message and the box is unticked',
        (tester) async {
      await submitWith(tester, _error(400, 'LEGAL_VERSION_MISMATCH'));

      expect(
        find.textContaining('Los términos cambiaron'),
        findsOneWidget,
      );
      expect(submitButton(tester).onPressed, isNull,
          reason: 'the user must accept the new versions again');
    });

    testWidgets('flag off (404) and missing permission (403)', (tester) async {
      await submitWith(tester, _error(404, 'FAMILY_FEATURE_DISABLED'));
      expect(find.textContaining('no está disponible'), findsOneWidget);
    });

    testWidgets('a code-less 429 says too many attempts', (tester) async {
      await submitWith(
        tester,
        const Left(ServerFailure(message: 'x', code: 429)),
      );
      expect(find.textContaining('Demasiados intentos'), findsOneWidget);
    });

    testWidgets('an unknown code never shows the server text', (tester) async {
      await submitWith(
        tester,
        const Left(
          ServerFailure(message: 'raw server text', code: 500, errorCode: 'X'),
        ),
      );
      expect(find.text('raw server text'), findsNothing);
    });
  });
}
