import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/login_view.dart';

import '../../../family/family_test_harness.dart';
import '../providers/auth_notifier_test_support.dart';

/// Bug de QA: `POST /auth/login` respondía bien y `GET /auth/me` daba 500; la
/// pantalla de login se vaciaba sin ningún mensaje. Con el router REAL y la
/// vista REAL.

const _loginUser = UserEntity(id: 'u1', email: 'ana@example.com', name: 'Ana');

class _Repo extends FakeAuthRepository {
  Either<Failure, UserEntity?> me =
      const Left(ServerFailure(message: 'RAW SERVER TEXT', code: 500));
  bool signedIn = false;
  int signOuts = 0;

  @override
  Future<bool> hasLocalToken() async => signedIn;

  /// Con red real hay fotogramas entre pasos: el router pasa por /splash y la
  /// pantalla de login se desmonta de verdad.
  static const _latency = Duration(milliseconds: 300);

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    await Future<void>.delayed(_latency);
    return me;
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);
    signedIn = true;
    return const Right(_loginUser);
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    signOuts++;
    signedIn = false;
    return const Right(null);
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  testWidgets(
      'a /auth/me 500 after a good login shows an error, keeps the email '
      'and leaves no half-logged-in session', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _Repo();
    SharedPreferences.setMockInitialValues({
      AppConstants.welcomeCarouselSeenKey: true,
    });
    final container = await buildAuthContainer(
      repo: repo,
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
      container.dispose();
    });
    container.listen(appBootstrapProvider, (_, __) {});
    await container.read(authNotifierProvider.future);
    final router = container.read(routerProvider);
    await pumpLocalizedRouterApp(tester, container, router);
    router.go(RouteNames.login);
    await _settle(tester);
    expect(find.byType(LoginView), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pump();
    tester
        .widgetList<SacButton>(find.byType(SacButton))
        .first
        .onPressed
        ?.call();
    await _settle(tester);

    // Volvió a la pantalla de login (nueva instancia) con el motivo a la vista.
    expect(find.byType(LoginView), findsOneWidget);
    expect(
      find.text(
        'Iniciaste sesión, pero no pudimos cargar tu cuenta. Inténtalo de '
        'nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('RAW SERVER TEXT'), findsNothing);
    // El correo escrito sigue ahí; la contraseña no se guarda.
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller?.text,
      'ana@example.com',
    );
    expect(tester.widget<TextFormField>(fields.at(1)).controller?.text, '');
    // Sin sesión a medias.
    expect(repo.signOuts, 1);
    expect(repo.signedIn, isFalse);
    expect(container.read(authNotifierProvider).valueOrNull, isNull);
  });

  testWidgets('a connection failure on /auth/me is explained as such',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _Repo()
      ..me = const Left(NetworkFailure(message: 'Sin conexión a internet'));
    SharedPreferences.setMockInitialValues({
      AppConstants.welcomeCarouselSeenKey: true,
    });
    final container = await buildAuthContainer(
      repo: repo,
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
      container.dispose();
    });
    container.listen(appBootstrapProvider, (_, __) {});
    await container.read(authNotifierProvider.future);
    final router = container.read(routerProvider);
    await pumpLocalizedRouterApp(tester, container, router);
    router.go(RouteNames.login);
    await _settle(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pump();
    tester
        .widgetList<SacButton>(find.byType(SacButton))
        .first
        .onPressed
        ?.call();
    await _settle(tester);

    expect(find.text('Error de conexión. Comprueba tu red.'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller?.text,
      'ana@example.com',
    );
  });
}
