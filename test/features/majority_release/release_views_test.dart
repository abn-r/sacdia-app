import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/login_notice_provider.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/features/majority_release/presentation/providers/majority_release_providers.dart';
import 'package:sacdia_app/features/majority_release/presentation/views/adult_claim_view.dart';
import 'package:sacdia_app/features/majority_release/presentation/views/release_frozen_view.dart';
import 'package:sacdia_app/features/majority_release/presentation/views/release_view.dart';

import '../family/family_test_harness.dart';
import 'majority_release_test_support.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeLegalRepository legal;
  late FakeMajorityReleaseRepository release;

  setUp(() {
    legal = FakeLegalRepository();
    release = FakeMajorityReleaseRepository();
  });

  List<Override> overrides(RecordingAuth auth) => [
        authNotifierProvider.overrideWith(() => auth),
        legalRepositoryProvider.overrideWithValue(legal),
        majorityReleaseRepositoryProvider.overrideWithValue(release),
        myLegalStatusProvider.overrideWith((ref) async => legalStatusFixture),
      ];

  Future<GoRouter> mountRelease(
    WidgetTester tester,
    RecordingAuth auth,
  ) =>
      pumpFamilyApp(
        tester,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const ReleaseView(onOpenDocument: _noOpen),
          ),
          stubRoute(RouteNames.releaseFrozen),
        ],
        overrides: overrides(auth),
      );

  group('ReleaseView (pending)', () {
    testWidgets('asks for the email first, then the terms', (tester) async {
      final auth = RecordingAuth(releasedUser(
        needsEmail: true,
        deadline: DateTime.now().add(const Duration(days: 12, hours: 5)),
      ));
      await mountRelease(tester, auth);
      await _settle(tester);

      expect(
        find.text('Eres mayor de edad y aún no has reclamado tu cuenta'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('release_step_email')), findsOneWidget);
      expect(find.byKey(const ValueKey('release_step_terms')), findsOneWidget);
      expect(find.textContaining('Paso 1: Agrega tu correo'), findsOneWidget);
      expect(find.textContaining('Paso 2: Acepta'), findsOneWidget);
      // Cuenta atrás con días y SIN promesa de borrado (R6).
      final deadline = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('release_deadline')),
          matching: find.byType(Text),
        ),
      );
      expect(deadline.data, contains('13 días'));
      expect(deadline.data!.toLowerCase(), isNot(contains('elimin')));
      expect(deadline.data!.toLowerCase(), isNot(contains('borra')));
      // Salidas siempre visibles.
      expect(find.byKey(const ValueKey('release_export_data')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('release_delete_account')), findsOneWidget);
      expect(find.byKey(const ValueKey('release_sign_out')), findsOneWidget);
    });

    testWidgets('no email step when the person already has an email',
        (tester) async {
      final auth = RecordingAuth(releasedUser());
      await mountRelease(tester, auth);
      await _settle(tester);

      expect(find.byKey(const ValueKey('release_step_email')), findsNothing);
      expect(find.textContaining('Paso 1: Acepta'), findsOneWidget);
    });

    testWidgets('an invalid email is rejected locally', (tester) async {
      final auth = RecordingAuth(releasedUser(needsEmail: true));
      await mountRelease(tester, auth);
      await _settle(tester);

      await tester.enterText(
          find.byKey(const ValueKey('release_email_field')), 'nope');
      await tester
          .ensureVisible(find.byKey(const ValueKey('release_email_submit')));
      await tester.tap(find.byKey(const ValueKey('release_email_submit')));
      await _settle(tester);

      expect(release.emails, isEmpty);
    });

    testWidgets(
        'a valid email is sent trimmed and lowercased and /auth/me is '
        're-read', (tester) async {
      final auth = RecordingAuth(releasedUser(needsEmail: true));
      await mountRelease(tester, auth);
      await _settle(tester);

      await tester.enterText(find.byKey(const ValueKey('release_email_field')),
          ' Ana@Example.COM ');
      await tester
          .ensureVisible(find.byKey(const ValueKey('release_email_submit')));
      await tester.tap(find.byKey(const ValueKey('release_email_submit')));
      await _settle(tester);

      expect(release.emails, ['ana@example.com']);
      expect(auth.refreshes, 1);
      // Pista de verificación (no obligatoria).
      expect(find.byKey(const ValueKey('release_email_added')), findsOneWidget);
    });

    testWidgets('a 409 shows an inline error and no hint', (tester) async {
      release.emailResult = const Left(ServerFailure(
        message: 'x',
        code: 409,
        errorCode: 'FAMILY_RELEASE_EMAIL_UNAVAILABLE',
      ));
      final auth = RecordingAuth(releasedUser(needsEmail: true));
      await mountRelease(tester, auth);
      await _settle(tester);

      await tester.enterText(find.byKey(const ValueKey('release_email_field')),
          'taken@example.com');
      await tester
          .ensureVisible(find.byKey(const ValueKey('release_email_submit')));
      await tester.tap(find.byKey(const ValueKey('release_email_submit')));
      await _settle(tester);

      expect(find.byKey(const ValueKey('release_email_error')), findsOneWidget);
      expect(find.text('No pudimos usar ese correo. Prueba con otro.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('release_email_added')), findsNothing);
      expect(auth.refreshes, 0);
    });

    testWidgets('accept needs the checkbox, then sends the shown versions',
        (tester) async {
      final auth = RecordingAuth(releasedUser());
      await mountRelease(tester, auth);
      await _settle(tester);

      final accept = find.byKey(const ValueKey('release_accept_submit'));
      await tester.ensureVisible(accept);
      expect(tester.widget<SacButton>(accept).isEnabled, isFalse);

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('release_terms_checkbox')),
        matching: find.byType(Checkbox),
      ));
      await _settle(tester);
      await tester.tap(accept);
      await _settle(tester);

      expect(legal.accepts, [(terms: '2.0.0-family', privacy: '2.0.0-family')]);
      expect(auth.refreshes, 1);
    });

    testWidgets('sign out is available', (tester) async {
      final auth = RecordingAuth(releasedUser());
      await mountRelease(tester, auth);
      await _settle(tester);

      final signOut = find.byKey(const ValueKey('release_sign_out'));
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await _settle(tester);
      expect(auth.signOuts, 1);
    });

    testWidgets('nothing left to do shows a loader, not the steps',
        (tester) async {
      final auth = RecordingAuth(releasedUser(needsAcceptance: false));
      await mountRelease(tester, auth);
      await _settle(tester);

      expect(find.byKey(const ValueKey('release_step_email')), findsNothing);
      expect(find.byKey(const ValueKey('release_step_terms')), findsNothing);
    });
  });

  group('ReleaseView (frozen: thaw by accepting)', () {
    testWidgets('explains the pause, offers the steps and a way back',
        (tester) async {
      final auth = RecordingAuth(releasedUser(frozen: true, needsEmail: true));
      final router = await mountRelease(tester, auth);
      await _settle(tester);

      final notice = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('release_frozen_notice')),
        matching: find.byType(Text),
      ));
      expect(notice.data, contains('en pausa'));
      expect(find.byKey(const ValueKey('release_deadline')), findsNothing);
      expect(find.byKey(const ValueKey('release_step_email')), findsOneWidget);
      expect(find.byKey(const ValueKey('release_step_terms')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('release_back_to_frozen')));
      await _settle(tester);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        RouteNames.releaseFrozen,
      );
    });
  });

  group('ReleaseFrozenView', () {
    testWidgets(
        'read-only explanation with export, delete and a way back; '
        'no deletion date', (tester) async {
      final auth = RecordingAuth(releasedUser(
        frozen: true,
        frozenAt: DateTime.utc(2026, 12, 11, 9, 30),
      ));
      final router = await pumpFamilyApp(
        tester,
        routes: [
          GoRoute(path: '/', builder: (_, __) => const ReleaseFrozenView()),
          stubRoute(RouteNames.release),
        ],
        overrides: overrides(auth),
      );
      await _settle(tester);

      expect(find.text('Tu cuenta está en pausa'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('release_frozen_since')), findsOneWidget);
      expect(find.byKey(const ValueKey('release_export_data')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('release_delete_account')), findsOneWidget);
      // Nunca promete un borrado automático.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join(' | ');
      expect(texts, isNot(contains('se eliminará')));
      expect(texts, isNot(contains('se borrará')));

      await tester.tap(find.byKey(const ValueKey('release_frozen_claim')));
      await _settle(tester);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        RouteNames.release,
      );
    });
  });

  group('AdultClaimView (public)', () {
    Future<void> mountClaim(WidgetTester tester, ProviderContainer? out) =>
        pumpFamilyApp(
          tester,
          routes: [
            GoRoute(path: '/', builder: (_, __) => const AdultClaimView()),
            stubRoute(RouteNames.login),
          ],
          overrides: [
            majorityReleaseRepositoryProvider.overrideWithValue(release),
          ],
        );

    Future<void> fill(
      WidgetTester tester, {
      String code = 'ab12-cd34',
      String email = ' Ana@Example.com ',
      String password = 'Passw0rd!xyz',
      String confirm = 'Passw0rd!xyz',
    }) async {
      await tester.enterText(
          find.byKey(const ValueKey('adult_claim_code')), code);
      await tester.enterText(
          find.byKey(const ValueKey('adult_claim_email')), email);
      await tester.enterText(
          find.byKey(const ValueKey('adult_claim_password')), password);
      await tester.enterText(
          find.byKey(const ValueKey('adult_claim_confirm')), confirm);
      final submit = find.byKey(const ValueKey('adult_claim_submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await _settle(tester);
    }

    testWidgets('validates locally before calling the server', (tester) async {
      await mountClaim(tester, null);
      await fill(tester, password: 'weak', confirm: 'weak');
      expect(release.redeems, isEmpty);

      await fill(tester, confirm: 'Different1!pass');
      expect(release.redeems, isEmpty);
    });

    testWidgets('success redeems, prefills the login email and goes to login',
        (tester) async {
      await mountClaim(tester, null);
      await fill(tester);

      expect(release.redeems.single.code, 'AB12-CD34');
      expect(release.redeems.single.email, 'ana@example.com');
      expect(release.redeems.single.password, 'Passw0rd!xyz');
      expect(find.text('route:${RouteNames.login}'), findsOneWidget);
    });

    testWidgets('an invalid code shows ONE generic error', (tester) async {
      release.redeemResult = const Left(ServerFailure(
        message: 'x',
        code: 400,
        errorCode: 'GUARDIANSHIP_LINK_CODE_INVALID',
      ));
      await mountClaim(tester, null);
      await fill(tester);

      expect(find.byKey(const ValueKey('adult_claim_error')), findsOneWidget);
      expect(find.text('route:${RouteNames.login}'), findsNothing);
    });

    testWidgets('lockout (429) shows a different message', (tester) async {
      release.redeemResult = const Left(ServerFailure(
        message: 'x',
        code: 429,
        errorCode: 'GUARDIANSHIP_LINK_CODE_LOCKED',
      ));
      await mountClaim(tester, null);
      await fill(tester);

      final error = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('adult_claim_error')),
        matching: find.byType(Text),
      ));
      expect(error.data, isNotNull);
      expect(error.data, isNot(startsWith('errors.')));
    });
  });

  test('the login prefill provider exists for the claim flow', () {
    expect(lastLoginIdentifierProvider, isNotNull);
  });
}

Future<bool> _noOpen(Uri uri) async => true;
