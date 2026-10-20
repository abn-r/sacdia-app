import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/family/data/models/dependent_models.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/domain/entities/supervised_login.dart';
import 'package:sacdia_app/features/family/presentation/views/enable_teen_login_wizard.dart';

import 'family_fixtures.dart';
import 'family_test_harness.dart';

DependentDetail _detail({
  int age = 14,
  bool milestone = true,
  String consent = 'verified',
  String accessMode = 'guardian_managed',
}) =>
    FamilyJson.detail(
      detailJson(
        age: age,
        consent: consent,
        ageMilestoneReached: milestone,
        accessMode: accessMode,
        guardians: [guardianJson(consent: consent)],
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeFamilyRepository repo;
  late FakeAuthNotifier auth;
  late List<String> clipboard;

  setUp(() {
    repo = FakeFamilyRepository();
    auth = FakeAuthNotifier();
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

  Future<({GoRouter router, ProviderContainer container})> pump(
    WidgetTester tester, {
    ActingForSession? session,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = await pumpFamilyApp(
      tester,
      overrides: [
        ...familyOverrides(repo: repo, auth: auth),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
      initialLocation: '/family',
      routes: [
        stubRoute('/family'),
        GoRoute(
          path: '/family/:dependentId/teen-login',
          builder: (_, state) => EnableTeenLoginWizard(
            dependentId: state.pathParameters['dependentId']!,
          ),
        ),
      ],
    );
    unawaited(router.push('/family/ana-1/teen-login'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EnableTeenLoginWizard)),
    );
    return (router: router, container: container);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fillPasswords(
    WidgetTester tester, {
    String password = 'Password123',
    String confirm = 'Password123',
    String? email,
  }) async {
    final fields = find.byType(TextFormField);
    var i = 0;
    if (email != null) await tester.enterText(fields.at(i++), email);
    await tester.enterText(fields.at(i++), password);
    await tester.enterText(fields.at(i), confirm);
    await tester.pump();
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  group('eligibility', () {
    testWidgets('a 12-year-old has no wizard, only the explanation',
        (tester) async {
      repo.detail = Right(_detail(age: 12, milestone: false));
      await pump(tester);

      expect(
          find.text('Ana aún no puede tener acceso propio.'), findsOneWidget);
      expect(find.text('Con un usuario'), findsNothing);
      expect(find.text('Activar acceso'), findsNothing);
    });

    testWidgets('a pending guardian cannot use the wizard', (tester) async {
      repo.detail = Right(_detail(consent: 'pending'));
      await pump(tester);

      expect(find.text('Con un usuario'), findsNothing);
    });

    testWidgets('a minor who already has an own login cannot enable it again',
        (tester) async {
      repo.detail = Right(_detail(accessMode: 'supervised_login'));
      await pump(tester);

      expect(find.text('Con un usuario'), findsNothing);
    });
  });

  group('handle flow', () {
    setUp(() => repo.detail = Right(_detail()));

    testWidgets('walks the four steps and shows the generated handle',
        (tester) async {
      await pump(tester);

      // 1. método
      expect(find.text('Paso 1 de 4'), findsOneWidget);
      expect(find.text('¿Cómo entrará Ana?'), findsOneWidget);
      expect(find.text('Con un usuario'), findsOneWidget);
      expect(find.text('Con su correo'), findsOneWidget);
      await tapText(tester, 'Siguiente');

      // 2. datos: sin campo de correo
      expect(find.text('Paso 2 de 4'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        find.text('Mínimo 8 caracteres, con mayúscula, minúscula y número.'),
        findsOneWidget,
      );
      await fillPasswords(tester);
      await tapText(tester, 'Siguiente');

      // 3. advertencias
      expect(find.text('Paso 3 de 4'), findsOneWidget);
      expect(
        find.text('Dejarás de poder actuar por Ana: usará su propio acceso.'),
        findsOneWidget,
      );
      expect(
        find.text('Si Ana tiene teléfonos vinculados, se desvincularán.'),
        findsOneWidget,
      );
      expect(repo.enableCalls, isEmpty);
      await tapText(tester, 'Activar acceso');

      // 4. resultado
      expect(repo.enableCalls, [
        (
          dependentId: 'ana-1',
          method: SupervisedLoginMethod.handle,
          password: 'Password123',
          email: null,
        ),
      ]);
      expect(find.text('Paso 4 de 4'), findsOneWidget);
      expect(find.text('Acceso activado'), findsOneWidget);
      expect(find.text('ana-7kq4m9'), findsOneWidget);
    });

    testWidgets('the result lets the guardian copy the handle', (tester) async {
      await pump(tester);
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester);
      await tapText(tester, 'Siguiente');
      await tapText(tester, 'Activar acceso');

      await tapText(tester, 'Copiar usuario');

      expect(clipboard, ['ana-7kq4m9']);
    });

    testWidgets('a weak password stops at the credentials step',
        (tester) async {
      await pump(tester);
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester, password: 'corta', confirm: 'corta');
      await tapText(tester, 'Siguiente');

      expect(find.text('Paso 2 de 4'), findsOneWidget);
      expect(repo.enableCalls, isEmpty);
    });

    testWidgets('a mismatched confirmation stops at the credentials step',
        (tester) async {
      await pump(tester);
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester, confirm: 'Password124');
      await tapText(tester, 'Siguiente');

      expect(find.text('Paso 2 de 4'), findsOneWidget);
      expect(repo.enableCalls, isEmpty);
    });

    testWidgets('back goes one step at a time and keeps what was typed',
        (tester) async {
      await pump(tester);
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester);
      await tapText(tester, 'Siguiente');
      expect(find.text('Paso 3 de 4'), findsOneWidget);

      await tapText(tester, 'Volver');
      expect(find.text('Paso 2 de 4'), findsOneWidget);
      await tapText(tester, 'Volver');
      expect(find.text('Paso 1 de 4'), findsOneWidget);
    });

    testWidgets('a server refusal is explained by code and stays on confirm',
        (tester) async {
      repo.enabled = const Left(
        ServerFailure(
          message: 'RAW',
          code: 422,
          errorCode: 'SUPERVISED_LOGIN_AGE_OUT_OF_RANGE',
        ),
      );
      await pump(tester);
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester);
      await tapText(tester, 'Siguiente');
      await tapText(tester, 'Activar acceso');

      expect(find.byKey(const ValueKey('wizard_error')), findsOneWidget);
      expect(find.textContaining('RAW'), findsNothing);
      expect(find.text('Paso 3 de 4'), findsOneWidget);
    });

    testWidgets('a rejected password sends the guardian back to fix it',
        (tester) async {
      repo.enabled = const Left(
        ServerFailure(
          message: 'RAW',
          code: 422,
          errorCode: 'SUPERVISED_LOGIN_PASSWORD_INVALID',
        ),
      );
      await pump(tester);
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester);
      await tapText(tester, 'Siguiente');
      await tapText(tester, 'Activar acceso');

      expect(find.text('Paso 2 de 4'), findsOneWidget);
      expect(
        find.text('La contraseña no cumple los requisitos de seguridad.'),
        findsOneWidget,
      );
    });
  });

  group('email flow', () {
    setUp(() => repo.detail = Right(_detail()));

    testWidgets('asks for the email and sends it with the password',
        (tester) async {
      repo.enabled = const Right(
        EnabledSupervisedLogin(
          supervisedLogin: SupervisedLoginInfo(
            method: SupervisedLoginMethod.email,
            email: 'ana@example.com',
          ),
        ),
      );
      await pump(tester);
      await tapText(tester, 'Con su correo');
      await tapText(tester, 'Siguiente');

      expect(find.byType(TextFormField), findsNWidgets(3));
      await fillPasswords(tester, email: 'ana@example.com');
      await tapText(tester, 'Siguiente');
      await tapText(tester, 'Activar acceso');

      expect(repo.enableCalls.single.method, SupervisedLoginMethod.email);
      expect(repo.enableCalls.single.email, 'ana@example.com');
      expect(find.text('ana@example.com'), findsOneWidget);
      // Un acceso por correo no tiene usuario que copiar.
      expect(find.text('Copiar usuario'), findsNothing);
    });

    testWidgets('an invalid email stops at the credentials step',
        (tester) async {
      await pump(tester);
      await tapText(tester, 'Con su correo');
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester, email: 'no-es-un-correo');
      await tapText(tester, 'Siguiente');

      expect(find.text('Paso 2 de 4'), findsOneWidget);
      expect(repo.enableCalls, isEmpty);
    });

    testWidgets('an unavailable email goes back to fix it', (tester) async {
      repo.enabled = const Left(
        ServerFailure(
          message: 'RAW',
          code: 409,
          errorCode: 'SUPERVISED_LOGIN_EMAIL_UNAVAILABLE',
        ),
      );
      await pump(tester);
      await tapText(tester, 'Con su correo');
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester, email: 'ana@example.com');
      await tapText(tester, 'Siguiente');
      await tapText(tester, 'Activar acceso');

      expect(find.text('Paso 2 de 4'), findsOneWidget);
      expect(find.text('Ese correo no está disponible. Prueba con otro.'),
          findsOneWidget);
    });
  });

  group('finishing', () {
    setUp(() => repo.detail = Right(_detail()));

    Future<void> activate(WidgetTester tester) async {
      await tapText(tester, 'Siguiente');
      await fillPasswords(tester);
      await tapText(tester, 'Siguiente');
      await tapText(tester, 'Activar acceso');
    }

    testWidgets('done returns to the family list', (tester) async {
      final h = await pump(tester);
      await activate(tester);

      await tapText(tester, 'Listo');

      expect(location(h.router), '/family');
      expect(auth.switchCalls, isEmpty);
    });

    testWidgets('while acting for this minor, it exits acting first',
        (tester) async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      final h = await pump(tester, session: session);
      await activate(tester);

      await tapText(tester, 'Listo');

      expect(auth.switchCalls, [(id: null, firstName: null)]);
      expect(location(h.router), '/family');
    });

    testWidgets('acting for ANOTHER minor is left alone', (tester) async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'luis-1', firstName: 'Luis'));
      await pump(tester, session: session);
      await activate(tester);

      await tapText(tester, 'Listo');

      expect(auth.switchCalls, isEmpty);
    });

    testWidgets('the result clears what was typed', (tester) async {
      await pump(tester);
      await activate(tester);

      // Ya no queda ningún campo con la contraseña en pantalla.
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Password123'), findsNothing);
    });
  });
}
