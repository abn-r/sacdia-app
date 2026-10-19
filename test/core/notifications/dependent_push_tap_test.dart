import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/notifications/dependent_push_tap_handler.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/providers/family_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/family/family_fixtures.dart';
import '../../features/family/family_test_harness.dart';

/// `AuthNotifier` cuya carga inicial se controla desde el test (arranque en
/// frío: la sesión del tutor tarda en llegar).
class _GatedAuth extends FakeAuthNotifier {
  _GatedAuth({UserEntity? user = guardianUser, this.gate}) : super(user);

  /// Si se pasa, `build` espera a que se complete.
  final Completer<void>? gate;

  @override
  Future<UserEntity?> build() async {
    await gate?.future;
    return user;
  }
}

/// Registra lo que el handler pidió hacer.
class _Probe {
  int ready = 0;
  Completer<void>? listGate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late GlobalKey<NavigatorState> navKey;

  setUp(() {
    navKey = GlobalKey<NavigatorState>();
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required _GatedAuth auth,
    Future<FamilyOverview> Function()? overview,
    ActingForSession? session,
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        dependentsProvider.overrideWith(
          (ref) =>
              overview?.call() ??
              Future.value(
                FamilyOverview(
                  dependents: [
                    summary(),
                    summary(id: 'luis-1', name: 'Luis'),
                    summary(id: 'eva-1', name: 'Eva', frozen: true),
                  ],
                  maxDependents: 10,
                ),
              ),
        ),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const FileAssetLoader(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              navigatorKey: navKey,
              theme: AppTheme.lightTheme,
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(0.5),
                ),
                child: child!,
              ),
              home: home ?? const Scaffold(body: Text('home')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  DependentPushTapHandler handlerOf(ProviderContainer container) {
    late DependentPushTapHandler handler;
    container.read(
      Provider((ref) {
        handler = DependentPushTapHandler(
          ref: ref,
          navigatorKey: navKey,
          sessionTimeout: const Duration(seconds: 2),
          lookupTimeout: const Duration(milliseconds: 500),
        );
        return handler;
      }),
    );
    return handler;
  }

  const dialogBody = 'Esta notificación es de Ana. ¿Cambiar a su perfil?';

  group('DependentPushTapHandler', () {
    test('dependentIdOf reads only a non-empty dependent_user_id', () {
      expect(
        DependentPushTapHandler.dependentIdOf({'dependent_user_id': ' ana-1 '}),
        'ana-1',
      );
      expect(DependentPushTapHandler.dependentIdOf({}), isNull);
      expect(
        DependentPushTapHandler.dependentIdOf({'dependent_user_id': ''}),
        isNull,
      );
    });

    testWidgets('asks first; Accept switches with the LIST id and navigates',
        (tester) async {
      final auth = _GatedAuth();
      final container = await pumpApp(tester, auth: auth);
      final probe = _Probe();

      unawaited(
        handlerOf(container).handle('ana-1', onReady: () => probe.ready++),
      );
      await tester.pumpAndSettle();

      expect(find.text(dialogBody), findsOneWidget);
      expect(auth.switchCalls, isEmpty);

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(auth.switchCalls.single, (id: 'ana-1', firstName: 'Ana'));
      expect(probe.ready, 1);
    });

    testWidgets('Cancel does nothing', (tester) async {
      final auth = _GatedAuth();
      final container = await pumpApp(tester, auth: auth);
      final probe = _Probe();

      unawaited(
        handlerOf(container).handle('ana-1', onReady: () => probe.ready++),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(auth.switchCalls, isEmpty);
      expect(probe.ready, 0);
    });

    testWidgets('a dependent that is not in the list: no dialog, no switch',
        (tester) async {
      final auth = _GatedAuth();
      final container = await pumpApp(tester, auth: auth);
      final probe = _Probe();

      unawaited(
        handlerOf(container)
            .handle('someone-elses-child', onReady: () => probe.ready++),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cambiar'), findsNothing);
      expect(find.text('Ese perfil ya no está disponible para ti.'),
          findsOneWidget);
      expect(auth.switchCalls, isEmpty);
      expect(probe.ready, 0);
    });

    testWidgets('a frozen dependent is treated as unavailable', (tester) async {
      final auth = _GatedAuth();
      final container = await pumpApp(tester, auth: auth);

      unawaited(handlerOf(container).handle('eva-1', onReady: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Ese perfil ya no está disponible para ti.'),
          findsOneWidget);
      expect(auth.switchCalls, isEmpty);
    });

    testWidgets('a failed lookup never switches', (tester) async {
      final auth = _GatedAuth();
      final container = await pumpApp(
        tester,
        auth: auth,
        overview: () async => throw const NetworkFailure(message: 'offline'),
      );

      unawaited(handlerOf(container).handle('ana-1', onReady: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar'), findsNothing);
      expect(find.text('Ese perfil ya no está disponible para ti.'),
          findsOneWidget);
      expect(auth.switchCalls, isEmpty);
    });

    testWidgets('already acting for that dependent: no dialog, just go',
        (tester) async {
      final auth = _GatedAuth();
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      final container = await pumpApp(tester, auth: auth, session: session);
      final probe = _Probe();

      unawaited(
        handlerOf(container).handle('ana-1', onReady: () => probe.ready++),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cambiar'), findsNothing);
      expect(auth.switchCalls, isEmpty);
      expect(probe.ready, 1);
    });

    testWidgets('cold start: waits for the guardian session before asking',
        (tester) async {
      final gate = Completer<void>();
      final auth = _GatedAuth(gate: gate);
      final container = await pumpApp(tester, auth: auth);
      final probe = _Probe();

      unawaited(
        handlerOf(container).handle('ana-1', onReady: () => probe.ready++),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // La sesión sigue cargando: aún no hay diálogo ni consulta.
      expect(find.text(dialogBody), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text(dialogBody), findsOneWidget);
    });

    testWidgets('no session (logged out): nothing is shown', (tester) async {
      final auth = _GatedAuth(user: null);
      final container = await pumpApp(tester, auth: auth);
      final probe = _Probe();

      unawaited(
        handlerOf(container).handle('ana-1', onReady: () => probe.ready++),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cambiar'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(probe.ready, 0);
    });

    testWidgets('offline switch does not navigate and says why',
        (tester) async {
      final auth = _GatedAuth()..outcome = SwitchProfileOutcome.offline;
      final container = await pumpApp(tester, auth: auth);
      final probe = _Probe();

      unawaited(
        handlerOf(container).handle('ana-1', onReady: () => probe.ready++),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(probe.ready, 0);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a second tap while the dialog is open is ignored',
        (tester) async {
      final auth = _GatedAuth();
      final container = await pumpApp(tester, auth: auth);
      final handler = handlerOf(container);

      unawaited(handler.handle('ana-1', onReady: () {}));
      await tester.pumpAndSettle();
      unawaited(handler.handle('luis-1', onReady: () {}));
      await tester.pumpAndSettle();

      expect(find.text(dialogBody), findsOneWidget);
      expect(find.text('Esta notificación es de Luis. ¿Cambiar a su perfil?'),
          findsNothing);
    });
  });

  group('PushNotificationService', () {
    late List<String> visited;

    Future<PushNotificationService> pumpRouter(
      WidgetTester tester, {
      required _GatedAuth auth,
    }) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      visited = [];
      Page<void> stub(GoRouterState state) {
        visited.add(state.uri.toString());
        return MaterialPage<void>(
          key: state.pageKey,
          child: Scaffold(body: Text('screen ${state.uri}')),
        );
      }

      final router = GoRouter(
        navigatorKey: navKey,
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            pageBuilder: (_, state) => MaterialPage<void>(
              key: state.pageKey,
              child: const Scaffold(body: Text('start')),
            ),
          ),
          GoRoute(
            path: RouteNames.homeDashboard,
            pageBuilder: (_, state) => stub(state),
          ),
          GoRoute(
            path: RouteNames.homeClasses,
            pageBuilder: (_, state) => stub(state),
          ),
        ],
      );
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => auth),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          dependentsProvider.overrideWith(
            (ref) async => FamilyOverview(
              dependents: [summary()],
              maxDependents: 10,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      late PushNotificationService service;
      container.read(
        Provider((ref) {
          service = PushNotificationService(
            dio: Dio(),
            ref: ref,
            navigatorKey: navKey,
          );
          return service;
        }),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            path: 'assets/translations',
            assetLoader: const FileAssetLoader(),
            fallbackLocale: const Locale('es'),
            startLocale: const Locale('es'),
            child: Builder(
              builder: (context) => MaterialApp.router(
                theme: AppTheme.lightTheme,
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(0.5),
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return service;
    }

    testWidgets(
        'tap on a dependent push asks, switches, goes home, then to '
        'the pushed route', (tester) async {
      final auth = _GatedAuth();
      final service = await pumpRouter(tester, auth: auth);

      service.handleNotificationTapForTesting(
        RemoteMessage(
          data: const {
            'dependent_user_id': 'ana-1',
            'route': RouteNames.homeClasses,
          },
        ),
      );
      await tester.pumpAndSettle();

      // Nada se navega antes de aceptar.
      expect(visited, isEmpty);
      expect(find.text(dialogBody), findsOneWidget);

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(auth.switchCalls.single.id, 'ana-1');
      expect(visited, contains(RouteNames.homeClasses));
    });

    testWidgets('Cancel on the dialog never navigates', (tester) async {
      final auth = _GatedAuth();
      final service = await pumpRouter(tester, auth: auth);

      service.handleNotificationTapForTesting(
        RemoteMessage(
          data: const {
            'dependent_user_id': 'ana-1',
            'route': RouteNames.homeClasses,
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(visited, isEmpty);
      expect(auth.switchCalls, isEmpty);
    });

    testWidgets('a push without dependent_user_id keeps the normal routing',
        (tester) async {
      final auth = _GatedAuth();
      final service = await pumpRouter(tester, auth: auth);

      service.handleNotificationTapForTesting(
        RemoteMessage(data: const {'route': RouteNames.homeClasses}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cambiar'), findsNothing);
      expect(visited, [RouteNames.homeClasses]);
      expect(auth.switchCalls, isEmpty);
    });

    testWidgets(
        'foreground dependent push shows the labelled banner without touching '
        'the guardian inbox counter or the achievement UI', (tester) async {
      final auth = _GatedAuth();
      final service = await pumpRouter(tester, auth: auth);
      final container = ProviderScope.containerOf(
        tester.element(find.text('start')),
      );

      service.handleForegroundMessageForTesting(
        RemoteMessage(
          notification: const RemoteNotification(
            title: 'Ana · Nuevo logro',
            body: 'Completó una clase',
          ),
          data: const {
            'type': 'achievement_unlocked',
            'dependent_user_id': 'ana-1',
          },
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('foreground-notification-banner')),
          findsOneWidget);
      expect(find.text('Ana · Nuevo logro'), findsOneWidget);
      expect(
          find.byKey(const Key('achievement-unlocked-snackbar')), findsNothing);
      expect(container.read(unreadNotificationsCountProvider), 0);
    });

    testWidgets('foreground push of the guardian itself still counts',
        (tester) async {
      final auth = _GatedAuth();
      final service = await pumpRouter(tester, auth: auth);
      final container = ProviderScope.containerOf(
        tester.element(find.text('start')),
      );

      service.handleForegroundMessageForTesting(
        RemoteMessage(
          notification: const RemoteNotification(
            title: 'Aviso',
            body: 'Cuerpo',
          ),
          data: const {'type': 'generic'},
        ),
      );
      await tester.pump();

      expect(container.read(unreadNotificationsCountProvider), 1);
    });
  });
}
