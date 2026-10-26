import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/family/data/models/dependent_models.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/views/dependent_detail_view.dart';

import 'family_fixtures.dart';
import 'family_test_harness.dart';

const _handleLogin = {
  'method': 'handle',
  'login_handle': 'ana-7kq4m9',
  'enabled_at': '2026-10-19T10:00:00.000Z',
  'disabled_at': null,
};

const _disabledHandleLogin = {
  'method': 'handle',
  'login_handle': 'ana-7kq4m9',
  'enabled_at': '2026-10-19T10:00:00.000Z',
  'disabled_at': '2026-10-20T10:00:00.000Z',
  'disabled_reason': 'guardian',
};

DependentDetail _detail({
  String consent = 'verified',
  int age = 14,
  String accessMode = 'guardian_managed',
  Map<String, Object?>? login,
  bool milestone = true,
}) =>
    FamilyJson.detail(
      detailJson(
        consent: consent,
        age: age,
        accessMode: accessMode,
        supervisedLogin: login,
        ageMilestoneReached: milestone,
        guardians: [guardianJson(consent: consent)],
      ),
    );

UserEntity _guardian({bool teenLogin = true}) => UserEntity(
      id: 'guardian-1',
      name: 'María',
      postRegisterComplete: true,
      familyFeatures: FamilyFeatures(teenLogin: teenLogin),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeFamilyRepository repo;
  late FakeAuthNotifier auth;
  late List<String> clipboard;

  setUp(() {
    repo = FakeFamilyRepository();
    auth = FakeAuthNotifier(_guardian());
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<GoRouter> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = await pumpFamilyApp(
      tester,
      overrides: familyOverrides(repo: repo, auth: auth),
      initialLocation: '/family',
      routes: [
        stubRoute('/family'),
        stubRoute('/family/:dependentId/teen-login'),
        stubRoute('/family/:dependentId/summary'),
        GoRoute(
          path: '/family/:dependentId',
          builder: (_, state) => DependentDetailView(
            dependentId: state.pathParameters['dependentId']!,
          ),
        ),
      ],
    );
    unawaited(router.push('/family/ana-1'));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('guardian without verified consent', () {
    testWidgets('sees only the explanation: no actions, no summary',
        (tester) async {
      repo.detail = Right(_detail(consent: 'pending'));
      await pump(tester);

      expect(find.byKey(const ValueKey('access_pending_guardian')),
          findsOneWidget);
      expect(find.text('Darle acceso propio'), findsNothing);
      expect(find.text('Ver resumen'), findsNothing);
      expect(find.text('Desactivar acceso'), findsNothing);
      expect(find.text('Restablecer contraseña'), findsNothing);
      // Lo único que sí puede: subir el formulario firmado.
      expect(find.text('Ficha de consentimiento'), findsOneWidget);
    });

    testWidgets(
        'even with an own login on record, the pending guardian '
        'cannot manage it', (tester) async {
      repo.detail = Right(_detail(
        consent: 'pending',
        accessMode: 'supervised_login',
        login: _handleLogin,
      ));
      await pump(tester);

      expect(find.text('Desactivar acceso'), findsNothing);
      expect(find.text('Restablecer contraseña'), findsNothing);
      expect(find.byKey(const ValueKey('access_handle')), findsNothing);
    });
  });

  group('verified guardian, minor without an own login', () {
    testWidgets('a 14-year-old can be given an own login', (tester) async {
      repo.detail = Right(_detail());
      final router = await pump(tester);

      await tapText(tester, 'Darle acceso propio');

      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/family/ana-1/teen-login',
      );
    });

    testWidgets(
        'the age nudge: a minor who reached the minimum age gets the '
        'notice with the enable entry', (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);

      expect(find.byKey(const ValueKey('age_nudge')), findsOneWidget);
      expect(find.text('Ana ya puede tener su propio acceso'), findsOneWidget);
      expect(find.text('Darle acceso propio'), findsOneWidget);
    });

    testWidgets(
        'no nudge before the minimum age, with the flag off or with an '
        'own login', (tester) async {
      repo.detail = Right(_detail(age: 12, milestone: false));
      await pump(tester);
      expect(find.byKey(const ValueKey('age_nudge')), findsNothing);
    });

    testWidgets('no nudge when the feature flag is off', (tester) async {
      auth = FakeAuthNotifier(_guardian(teenLogin: false));
      repo.detail = Right(_detail());
      await pump(tester);

      expect(find.byKey(const ValueKey('age_nudge')), findsNothing);
    });

    testWidgets('a 12-year-old gets no entry, only the explanation',
        (tester) async {
      repo.detail = Right(_detail(age: 12, milestone: false));
      await pump(tester);

      expect(find.text('Darle acceso propio'), findsNothing);
      expect(find.byKey(const ValueKey('access_not_yet')), findsOneWidget);
    });

    testWidgets('with the feature flag off there is no entry', (tester) async {
      auth = FakeAuthNotifier(_guardian(teenLogin: false));
      repo.detail = Right(_detail());
      await pump(tester);

      expect(find.text('Darle acceso propio'), findsNothing);
      // El resumen no depende de la bandera.
      expect(find.text('Ver resumen'), findsOneWidget);
    });

    testWidgets('an unknown flag state (offline restore) also hides it',
        (tester) async {
      auth = FakeAuthNotifier(
        const UserEntity(id: 'guardian-1', postRegisterComplete: true),
      );
      repo.detail = Right(_detail());
      await pump(tester);

      expect(find.text('Darle acceso propio'), findsNothing);
    });

    testWidgets('the summary opens its own screen', (tester) async {
      repo.detail = Right(_detail());
      final router = await pump(tester);

      await tapText(tester, 'Ver resumen');

      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/family/ana-1/summary',
      );
    });

    testWidgets('"view as" is still offered while the minor has no own login',
        (tester) async {
      repo.detail = Right(_detail());
      await pump(tester);

      expect(find.text('Ver como Ana'), findsOneWidget);
    });
  });

  group('minor with an active own login', () {
    DependentDetail active() => _detail(
          accessMode: 'supervised_login',
          login: _handleLogin,
          milestone: false,
        );

    testWidgets('shows the handle, its copy action and the management buttons',
        (tester) async {
      repo.detail = Right(active());
      await pump(tester);

      expect(find.text('Acceso propio activo'), findsOneWidget);
      expect(find.text('ana-7kq4m9'), findsOneWidget);
      expect(find.text('Restablecer contraseña'), findsOneWidget);
      expect(find.text('Desactivar acceso'), findsOneWidget);
      expect(find.text('Ver resumen'), findsOneWidget);
      // Ya no se actúa por él.
      expect(find.text('Ver como Ana'), findsNothing);
      expect(find.text('Darle acceso propio'), findsNothing);
    });

    testWidgets('copying the handle puts it on the clipboard', (tester) async {
      repo.detail = Right(active());
      await pump(tester);

      await tester.ensureVisible(find.byTooltip('Copiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Copiar'));
      await tester.pumpAndSettle();

      expect(clipboard, ['ana-7kq4m9']);
      expect(find.text('Usuario copiado'), findsOneWidget);
    });

    testWidgets('disable warns first and then calls the endpoint',
        (tester) async {
      repo.detail = Right(active());
      await pump(tester);

      await tapText(tester, 'Desactivar acceso');
      expect(find.text('¿Desactivar el acceso de Ana?'), findsOneWidget);
      expect(repo.disableCalls, isEmpty);

      await tester.tap(find.text('Desactivar').last);
      await tester.pumpAndSettle();

      expect(repo.disableCalls, ['ana-1']);
      expect(find.text('Acceso desactivado'), findsWidgets);
    });

    testWidgets('cancelling the disable warning does nothing', (tester) async {
      repo.detail = Right(active());
      await pump(tester);

      await tapText(tester, 'Desactivar acceso');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.disableCalls, isEmpty);
    });

    testWidgets('a failed disable shows the mapped message, not raw text',
        (tester) async {
      repo.detail = Right(active());
      repo.disabled = const Left(
        ServerFailure(
          message: 'RAW',
          code: 404,
          errorCode: 'SUPERVISED_LOGIN_NOT_FOUND',
        ),
      );
      await pump(tester);

      await tapText(tester, 'Desactivar acceso');
      await tester.tap(find.text('Desactivar').last);
      await tester.pumpAndSettle();

      expect(find.text('Este perfil no tiene acceso propio.'), findsOneWidget);
      expect(find.textContaining('RAW'), findsNothing);
    });

    testWidgets('reset (usuario): the guardian chooses the new password',
        (tester) async {
      repo.detail = Right(active());
      await pump(tester);

      await tapText(tester, 'Restablecer contraseña');
      expect(find.text('Restablecer la contraseña de Ana'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'NuevaClave9!xy');
      await tester.enterText(fields.at(1), 'NuevaClave9!xy');
      await tester.tap(find.text('Restablecer').last);
      await tester.pumpAndSettle();

      expect(repo.passwordCalls, [
        (dependentId: 'ana-1', password: 'NuevaClave9!xy'),
      ]);
      expect(
        find.text('Contraseña restablecida. Sesiones cerradas: 2.'),
        findsOneWidget,
      );
    });

    testWidgets('a weak or mismatched password never reaches the server',
        (tester) async {
      repo.detail = Right(active());
      await pump(tester);

      await tapText(tester, 'Restablecer contraseña');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'corta');
      await tester.enterText(fields.at(1), 'otra');
      await tester.tap(find.text('Restablecer').last);
      await tester.pumpAndSettle();

      expect(repo.passwordCalls, isEmpty);
      // El diálogo sigue abierto con los errores de validación.
      expect(find.text('Restablecer la contraseña de Ana'), findsOneWidget);
    });

    testWidgets('reset (correo): only a confirmation, no password is asked',
        (tester) async {
      repo.detail = Right(_detail(
        accessMode: 'supervised_login',
        login: const {
          'method': 'email',
          'login_handle': null,
          'enabled_at': '2026-10-19T10:00:00.000Z',
          'disabled_at': null,
        },
        milestone: false,
      ));
      await pump(tester);

      await tapText(tester, 'Restablecer contraseña');
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Restablecer').last);
      await tester.pumpAndSettle();

      expect(repo.passwordCalls, [(dependentId: 'ana-1', password: null)]);
      expect(find.textContaining('correo de restablecimiento'), findsOneWidget);
    });

    testWidgets('with the flag off the management buttons disappear',
        (tester) async {
      auth = FakeAuthNotifier(_guardian(teenLogin: false));
      repo.detail = Right(active());
      await pump(tester);

      expect(find.text('Desactivar acceso'), findsNothing);
      expect(find.text('Restablecer contraseña'), findsNothing);
      expect(find.text('Ver resumen'), findsOneWidget);
    });
  });

  group('minor whose own login was disabled', () {
    DependentDetail disabled({String method = 'handle'}) => _detail(
          accessMode: 'guardian_managed',
          login: method == 'handle'
              ? _disabledHandleLogin
              : const {
                  'method': 'email',
                  'login_handle': null,
                  'disabled_at': '2026-10-20T10:00:00.000Z',
                  'disabled_reason': 'guardian',
                },
          milestone: false,
        );

    testWidgets('can be reactivated; a handle login asks for a NEW password',
        (tester) async {
      repo.detail = Right(disabled());
      await pump(tester);

      expect(find.text('Acceso desactivado'), findsOneWidget);
      await tapText(tester, 'Reactivar acceso');
      expect(find.text('Reactivar el acceso de Ana'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'OtraClave7!xyz');
      await tester.enterText(fields.at(1), 'OtraClave7!xyz');
      await tester.tap(find.text('Reactivar').last);
      await tester.pumpAndSettle();

      expect(repo.reactivateCalls, [
        (dependentId: 'ana-1', password: 'OtraClave7!xyz'),
      ]);
      expect(find.text('Acceso reactivado'), findsOneWidget);
    });

    testWidgets('an email login only asks to confirm', (tester) async {
      repo.detail = Right(disabled(method: 'email'));
      await pump(tester);

      await tapText(tester, 'Reactivar acceso');
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Reactivar').last);
      await tester.pumpAndSettle();

      expect(repo.reactivateCalls, [(dependentId: 'ana-1', password: null)]);
    });

    testWidgets('a disabled login is not "own login active": acting returns',
        (tester) async {
      repo.detail = Right(disabled());
      await pump(tester);

      expect(find.text('Ver como Ana'), findsOneWidget);
      expect(find.text('Desactivar acceso'), findsNothing);
    });

    testWidgets('a login closed by majority cannot be reactivated',
        (tester) async {
      repo.detail = Right(_detail(
        login: const {
          'method': 'handle',
          'login_handle': 'ana-7kq4m9',
          'disabled_at': '2026-10-20T10:00:00.000Z',
          'disabled_reason': 'age_majority',
        },
        milestone: false,
      ));
      await pump(tester);

      expect(find.text('Reactivar acceso'), findsNothing);
    });
  });

  test('canActAs excludes a minor with an active own login only', () {
    final active = FamilyJson.summary(dependentJson(
      accessMode: 'supervised_login',
      supervisedLogin: _handleLogin,
    ));
    final disabled = FamilyJson.summary(dependentJson(
      supervisedLogin: _disabledHandleLogin,
    ));
    final plain = FamilyJson.summary(dependentJson());

    expect(active.canActAs, isFalse);
    expect(disabled.canActAs, isTrue);
    expect(plain.canActAs, isTrue);
  });
}
