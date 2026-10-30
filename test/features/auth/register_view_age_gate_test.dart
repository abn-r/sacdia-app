import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_picker_field.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/registration_age_gate.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/register_view.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_status.dart';
import 'package:sacdia_app/features/legal/domain/repositories/legal_repository.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import '../../support/riverpod_test_support.dart';

/// FP-65: la fecha de nacimiento es obligatoria y un menor del mínimo nunca
/// llega a `/auth/register`. El 422 del servidor cae en la misma pantalla.

class _Legal implements LegalRepository {
  @override
  Future<Either<Failure, List<LegalDocument>>> getCurrentDocuments() async =>
      const Right([
        LegalDocument(
          documentType: LegalDocumentTypes.terms,
          version: '1.0.0',
          url: 'https://sacdia.com/terms',
        ),
        LegalDocument(
          documentType: LegalDocumentTypes.privacy,
          version: '1.0.0',
          url: 'https://sacdia.com/privacy',
        ),
      ]);

  @override
  Future<Either<Failure, LegalStatus>> getMyStatus() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, LegalStatus>> accept({
    required String termsVersion,
    required String privacyVersion,
  }) =>
      throw UnimplementedError();
}

class _Auth extends AuthNotifier {
  _Auth({this.serverRejectsAge = false});

  final bool serverRejectsAge;
  final birthdays = <String?>[];

  @override
  Future<UserEntity?> build() async => null;

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
    required String acceptedTermsVersion,
    required String acceptedPrivacyVersion,
    String? birthday,
  }) async {
    birthdays.add(birthday);
    state = serverRejectsAge
        ? AsyncValue.error(
            const RegistrationAgeBelowMinimum(),
            StackTrace.current,
          )
        : AsyncValue.error('boom', StackTrace.current);
    return false;
  }
}

const _gate = Key('register_age_gate');

Future<_Auth> _pump(WidgetTester tester, {_Auth? auth}) async {
  tester.view.physicalSize = const Size(900, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final notifier = auth ?? _Auth();
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => notifier),
        legalRepositoryProvider.overrideWithValue(_Legal()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.5),
          ),
          child: child!,
        ),
        home: const RegisterView(birthdayPicker: _fakePicker),
      ),
    ),
  );
  // La vista ya no observa el auth (en la app el router lo inicializa al
  // arrancar). Se lee aquí para que el build() del fake termine antes del
  // envío y no pise el error que deja signUp.
  ProviderScope.containerOf(tester.element(find.byType(RegisterView)))
      .read(authNotifierProvider);
  await tester.pump(const Duration(seconds: 2));
  return notifier;
}

Future<void> _fillText(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Ana');
  await tester.enterText(fields.at(1), 'Perez');
  await tester.enterText(fields.at(2), 'Lopez');
  await tester.enterText(fields.at(3), 'ana@example.com');
  await tester.enterText(fields.at(4), 'Password123!x');
  await tester.enterText(fields.at(5), 'Password123!x');
  await tester.pump();
}

/// El selector nativo se sustituye por una fecha fija (el diálogo de Material
/// no se pinta bien con el escalado de texto 0.5 de estos tests).
DateTime? _nextPick;

Future<DateTime?> _fakePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async =>
    _nextPick;

Future<void> _pickBirthday(WidgetTester tester, DateTime date) async {
  _nextPick = date;
  await tester.tap(find.byType(SacPickerField));
  await tester.pumpAndSettle();
}

DateTime _yearsAgo(int years, {int extraDays = 0}) {
  final now = DateTime.now();
  return DateTime(now.year - years, now.month, now.day - extraDays);
}

Future<void> _acceptLegal(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

Finder _registerButton() =>
    find.widgetWithText(SacButton, 'auth.register_button');

void main() {
  testWidgets('without a birthday the register button stays disabled',
      (tester) async {
    await _pump(tester);
    await _fillText(tester);
    await _acceptLegal(tester);

    expect(tester.widget<SacButton>(_registerButton()).isEnabled, isFalse);
  });

  testWidgets('age 12 blocks the form with the guardian message, no API call',
      (tester) async {
    final auth = await _pump(tester);
    await _fillText(tester);
    await _pickBirthday(tester, _yearsAgo(12));

    expect(find.byKey(_gate), findsOneWidget);
    expect(find.text('auth.register.age_gate.message'), findsOneWidget);
    expect(_registerButton(), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(auth.birthdays, isEmpty);
  });

  testWidgets('turning 13 today is allowed and the birthday is sent as ISO',
      (tester) async {
    final auth = await _pump(tester);
    await _fillText(tester);
    final birthday = _yearsAgo(13);
    await _pickBirthday(tester, birthday);
    await _acceptLegal(tester);

    expect(find.byKey(_gate), findsNothing);
    final button = tester.widget<SacButton>(_registerButton());
    expect(button.isEnabled, isTrue);

    button.onPressed!();
    await tester.pump();
    await tester.pump();

    expect(auth.birthdays, [formatBirthdayIso(birthday)]);
  });

  testWidgets('turning 13 tomorrow is still blocked', (tester) async {
    final auth = await _pump(tester);
    await _fillText(tester);
    await _pickBirthday(tester, _yearsAgo(13, extraDays: -1));

    expect(find.byKey(_gate), findsOneWidget);
    expect(auth.birthdays, isEmpty);
  });

  testWidgets('the server 422 shows the very same blocked screen',
      (tester) async {
    final auth = await _pump(tester, auth: _Auth(serverRejectsAge: true));
    await _fillText(tester);
    await _pickBirthday(tester, _yearsAgo(20));
    await _acceptLegal(tester);
    expect(find.byKey(_gate), findsNothing);

    tester.widget<SacButton>(_registerButton()).onPressed!();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(auth.birthdays, hasLength(1));
    expect(find.byKey(_gate), findsOneWidget);
    expect(find.text('auth.register.age_gate.message'), findsOneWidget);
    // No se muestra además la tarjeta de error genérica con el texto crudo.
    expect(find.text('AUTH_REGISTRATION_AGE_BELOW_MINIMUM'), findsNothing);
  });

  testWidgets(
      'a server error shows on the form and is cleared from the auth state '
      '(the login must not inherit it)', (tester) async {
    await _pump(tester);
    await _fillText(tester);
    await _pickBirthday(tester, _yearsAgo(20));
    await _acceptLegal(tester);

    tester.widget<SacButton>(_registerButton()).onPressed!();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('boom'), findsOneWidget);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(RegisterView)));
    expect(container.read(authNotifierProvider).hasError, isFalse);
  });

  testWidgets('correcting the birthday brings the form back', (tester) async {
    await _pump(tester);
    await _fillText(tester);
    await _pickBirthday(tester, _yearsAgo(12));
    expect(find.byKey(_gate), findsOneWidget);

    await tester.tap(find.text('auth.register.age_gate.fix'));
    await tester.pumpAndSettle();

    expect(find.byKey(_gate), findsNothing);
    expect(_registerButton(), findsOneWidget);
    expect(tester.widget<SacButton>(_registerButton()).isEnabled, isFalse);
  });

  group('registration age helpers', () {
    test('ageOn handles the day before and the day of the birthday', () {
      final today = DateTime(2026, 10, 19);
      expect(ageOn(DateTime(2013, 10, 20), today), 12);
      expect(ageOn(DateTime(2013, 10, 19), today), 13);
      expect(ageOn(DateTime(2013, 10, 18), today), 13);
    });

    test('a leap-day birthday turns a year older on Mar 1 in common years', () {
      expect(ageOn(DateTime(2012, 2, 29), DateTime(2025, 2, 28)), 12);
      expect(ageOn(DateTime(2012, 2, 29), DateTime(2025, 3, 1)), 13);
    });

    test('isBelowRegistrationMinAge honours a custom country minimum', () {
      final today = DateTime(2026, 10, 19);
      final birthday = DateTime(2011, 10, 19); // 15 años
      expect(isBelowRegistrationMinAge(birthday, today), isFalse);
      expect(isBelowRegistrationMinAge(birthday, today, minAge: 16), isTrue);
    });

    test('formatBirthdayIso pads month and day', () {
      expect(formatBirthdayIso(DateTime(2014, 3, 5)), '2014-03-05');
    });
  });

  group('supervised-account notice (FP3-31)', () {
    const notice = Key('register_minor_notice');

    testWidgets('a 15-year-old is told the account will be supervised',
        (tester) async {
      await _pump(tester);
      await _fillText(tester);
      await _pickBirthday(tester, _yearsAgo(15));

      expect(find.byKey(notice), findsOneWidget);
      expect(find.byKey(_gate), findsNothing);
    });

    testWidgets('turning 13 today already sees the notice', (tester) async {
      await _pump(tester);
      await _pickBirthday(tester, _yearsAgo(13));

      expect(find.byKey(notice), findsOneWidget);
    });

    testWidgets('an adult sees no notice', (tester) async {
      await _pump(tester);
      await _pickBirthday(tester, _yearsAgo(30));

      expect(find.byKey(notice), findsNothing);
    });

    testWidgets('turning 18 today sees no notice', (tester) async {
      await _pump(tester);
      await _pickBirthday(tester, _yearsAgo(18));

      expect(find.byKey(notice), findsNothing);
    });

    testWidgets('under 13 keeps the unchanged age gate and no notice',
        (tester) async {
      await _pump(tester);
      await _pickBirthday(tester, _yearsAgo(12));

      expect(find.byKey(_gate), findsOneWidget);
      expect(find.byKey(notice), findsNothing);
    });
  });
}
