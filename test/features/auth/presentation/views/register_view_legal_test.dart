import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_picker_field.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/register_view.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_status.dart';
import 'package:sacdia_app/features/legal/domain/repositories/legal_repository.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';

List<LegalDocument> _docs({String terms = '1.0.0', String privacy = '1.0.0'}) =>
    [
      LegalDocument(
        documentType: LegalDocumentTypes.terms,
        version: terms,
        url: 'https://sacdia.com/terms',
      ),
      LegalDocument(
        documentType: LegalDocumentTypes.privacy,
        version: privacy,
        url: 'https://sacdia.com/privacy',
      ),
    ];

class _FakeLegalRepository implements LegalRepository {
  /// Each call consumes the next entry (the last one repeats).
  List<Either<Failure, List<LegalDocument>>> queue = [Right(_docs())];
  int calls = 0;

  @override
  Future<Either<Failure, List<LegalDocument>>> getCurrentDocuments() async {
    final i = calls < queue.length ? calls : queue.length - 1;
    calls++;
    return queue[i];
  }

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

class _RecordingAuthNotifier extends AuthNotifier {
  final List<({String terms, String privacy})> sent = [];

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
    sent.add((terms: acceptedTermsVersion, privacy: acceptedPrivacyVersion));
    state = AsyncValue.error('boom', StackTrace.current);
    return false;
  }
}

class _Harness {
  _Harness(this.auth, this.repo);
  final _RecordingAuthNotifier auth;
  final _FakeLegalRepository repo;
}

Future<_Harness> _pump(
  WidgetTester tester,
  _FakeLegalRepository repo,
) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = _RecordingAuthNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        legalRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        // Raw localization keys render in the wide Ahem test font.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.5),
          ),
          child: child!,
        ),
        home: const RegisterView(),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  return _Harness(auth, repo);
}

Future<void> _fillForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Ana');
  await tester.enterText(fields.at(1), 'Perez');
  await tester.enterText(fields.at(2), 'Lopez');
  await tester.enterText(fields.at(3), 'ana@example.com');
  await tester.enterText(fields.at(4), 'Password123!x');
  await tester.enterText(fields.at(5), 'Password123!x');
  await tester.pump();
  // Fecha de nacimiento obligatoria: el selector abre en hace 18 años.
  await tester.tap(find.byType(SacPickerField));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

SacButton _registerButton(WidgetTester tester) => tester.widget<SacButton>(
      find.widgetWithText(SacButton, 'auth.register_button'),
    );

void main() {
  testWidgets('consent is unchecked by default and gates the button',
      (tester) async {
    await _pump(tester, _FakeLegalRepository());
    await _fillForm(tester);

    final checkbox = find.byType(Checkbox);
    expect(checkbox, findsOneWidget);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    expect(_registerButton(tester).isEnabled, isFalse);

    await tester.tap(checkbox);
    await tester.pump();

    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    expect(_registerButton(tester).isEnabled, isTrue);
  });

  testWidgets('checked consent alone does not enable an invalid form',
      (tester) async {
    await _pump(tester, _FakeLegalRepository());

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(_registerButton(tester).isEnabled, isFalse);
  });

  testWidgets('submits the versions returned by /legal/current',
      (tester) async {
    final repo = _FakeLegalRepository()
      ..queue = [Right(_docs(terms: '2.0.0', privacy: '3.0.0'))];
    final h = await _pump(tester, repo);
    await _fillForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    _registerButton(tester).onPressed!();
    await tester.pump();
    await tester.pump();

    expect(h.auth.sent, [(terms: '2.0.0', privacy: '3.0.0')]);
  });

  testWidgets('load error disables register and retry brings the checkbox',
      (tester) async {
    final repo = _FakeLegalRepository()
      ..queue = [
        const Left(ServerFailure(message: 'down', code: 500)),
        Right(_docs()),
      ];
    final h = await _pump(tester, repo);
    await _fillForm(tester);

    expect(find.text('auth.legal.load_error'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(_registerButton(tester).isEnabled, isFalse);

    await tester.tap(find.text('auth.legal.retry'));
    await tester.pump();
    await tester.pump();

    expect(h.repo.calls, 2);
    expect(find.text('auth.legal.load_error'), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets(
      'a failed sign-up refetches documents; changed versions '
      'uncheck the consent', (tester) async {
    final repo = _FakeLegalRepository()
      ..queue = [
        Right(_docs(terms: '1.0.0')),
        Right(_docs(terms: '2.0.0')),
      ];
    final h = await _pump(tester, repo);
    await _fillForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    _registerButton(tester).onPressed!();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(h.auth.sent, [(terms: '1.0.0', privacy: '1.0.0')]);
    expect(h.repo.calls, 2);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(_registerButton(tester).isEnabled, isFalse);
  });

  testWidgets('a failed sign-up with unchanged versions keeps the consent',
      (tester) async {
    final repo = _FakeLegalRepository()..queue = [Right(_docs())];
    final h = await _pump(tester, repo);
    await _fillForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    _registerButton(tester).onPressed!();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(h.repo.calls, 2);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
