import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/session_mode.dart';
import 'package:sacdia_app/core/config/device_pair_link.dart';
import 'package:sacdia_app/core/config/pending_navigation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/providers/profile_scope_registry.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/profile_scope_purge.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_connectivity_provider.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/qr/domain/entities/qr_member_token.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';
import 'package:sacdia_app/providers/json_file_cache_provider.dart';
import 'package:sacdia_app/core/storage/json_file_cache.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/device_mode/device_test_harness.dart';
import '../../features/family/family_test_harness.dart';

class _GatedAuth extends AuthNotifier {
  _GatedAuth(this.user, {this.gate});

  UserEntity? user;
  final Completer<void>? gate;

  @override
  Future<UserEntity?> build() async {
    if (gate != null) await gate!.future;
    return user;
  }

  void emit(UserEntity? next) => state = AsyncValue.data(next);
}

class _ReadyBootstrap extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

class _FakeQr extends QrMemberTokenNotifier {
  @override
  Future<QrMemberToken> build() async => QrMemberToken(
        token: 'QR',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        expiresIn: 3600,
      );
}

int _sentinelBuilds = 0;
final _sentinel = Provider<int>((ref) => ++_sentinelBuilds);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  setUp(() {
    _sentinelBuilds = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (_) async => true,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  Future<
      ({
        ProviderContainer container,
        GoRouter router,
        Completer<void> gate,
        PushNotificationService push,
        _GatedAuth auth,
      })> pumpApp(
    WidgetTester tester,
    UserEntity? user, {
    bool withGate = true,
    bool online = true,
    bool withSentinel = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gate = Completer<void>();
    final auth = _GatedAuth(user, gate: withGate ? gate : null);
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        jsonFileCacheProvider.overrideWithValue(MemoryJsonFileCache()),
        sessionModeProvider.overrideWith(
          (ref) => user != null && user.isLinkedDevice
              ? SessionMode.device
              : SessionMode.account,
        ),
        notificationsRepositoryProvider
            .overrideWithValue(FakeNotificationsRepository()),
        userClassesProvider.overrideWith((ref) async => const [mathClass]),
        classWithProgressProvider
            .overrideWith((ref, q) async => classWithProgress()),
        clubActivitiesProvider
            .overrideWith((ref, params) async => [activity(1)]),
        activityDetailProvider.overrideWith((ref, id) async => activity(id)),
        qrMemberTokenProvider.overrideWith(_FakeQr.new),
        deviceOnlineProvider.overrideWith((ref) => Stream.value(online)),
        if (withSentinel)
          profileScopedProvidersProvider
              .overrideWithValue([...profileScopedProviders, _sentinel]),
      ],
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
      container.dispose();
    });
    if (!withGate) await container.read(authNotifierProvider.future);
    final push = PushNotificationService(
      dio: Dio(),
      ref: container.read(Provider<Ref>((ref) => ref)),
      navigatorKey: pushNavigatorKey,
    );
    final router = container.read(routerProvider);
    await pumpLocalizedRouterApp(tester, container, router);
    return (
      container: container,
      router: router,
      gate: gate,
      push: push,
      auth: auth,
    );
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  group('REAL router + REAL views: the device shell', () {
    testWidgets('a cold start in device mode opens the device home',
        (tester) async {
      final app = await pumpApp(tester, deviceUser());
      expect(location(app.router), RouteNames.splash);

      app.gate.complete();
      await _settle(tester);

      expect(location(app.router), RouteNames.deviceHome);
      expect(find.text('Hola, Ana'), findsOneWidget);
      // Cuatro pestañas, nada más.
      for (final label in ['Inicio', 'Clases', 'Agenda', 'Avisos']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Perfil'), findsNothing);
    });

    testWidgets('the tabs switch between the four sections', (tester) async {
      final app = await pumpApp(tester, deviceUser(), withGate: false);
      app.router.go(RouteNames.deviceHome);
      await _settle(tester);

      await tester.tap(find.text('Clases').last);
      await _settle(tester);
      expect(location(app.router), RouteNames.deviceClasses);
      expect(find.text('Mis clases'), findsOneWidget);

      await tester.tap(find.text('Agenda').last);
      await _settle(tester);
      expect(location(app.router), RouteNames.deviceAgenda);
      expect(find.text('Campamento'), findsOneWidget);

      await tester.tap(find.text('Avisos').last);
      await _settle(tester);
      expect(location(app.router), RouteNames.deviceInbox);
    });

    testWidgets('a deep link into Mi familia, security or login goes home',
        (tester) async {
      final app = await pumpApp(tester, deviceUser(), withGate: false);
      app.router.go(RouteNames.deviceHome);
      await _settle(tester);

      for (final path in [
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.login,
        RouteNames.homeProfile,
        '/security/sessions',
      ]) {
        app.router.go(path);
        await _settle(tester);
        expect(location(app.router), RouteNames.deviceHome, reason: path);
      }
    });

    testWidgets('offline shows the banner on every tab', (tester) async {
      final app =
          await pumpApp(tester, deviceUser(), withGate: false, online: false);
      app.router.go(RouteNames.deviceHome);
      await _settle(tester);

      expect(
          find.byKey(const ValueKey('device_offline_banner')), findsOneWidget);
    });

    testWidgets('pending terms block the whole shell', (tester) async {
      final app = await pumpApp(
        tester,
        deviceUser(legalPending: true),
        withGate: false,
      );
      app.router.go(RouteNames.deviceClasses);
      await _settle(tester);

      expect(location(app.router), RouteNames.deviceLegalBlock);
      expect(find.text('Falta un paso de tu tutor'), findsOneWidget);
    });

    testWidgets('an incomplete registration shows the pending screen',
        (tester) async {
      final app = await pumpApp(
        tester,
        deviceUser(postRegisterComplete: false),
        withGate: false,
      );
      app.router.go(RouteNames.postRegistration);
      await _settle(tester);

      expect(location(app.router), RouteNames.deviceRegistrationPending);
    });
  });

  group('REAL router: a push that arrives while the device session loads', () {
    testWidgets(
        'is delivered once the session is ready if the device may open it',
        (tester) async {
      final app = await pumpApp(tester, deviceUser());
      expect(location(app.router), RouteNames.splash);

      // `/class/3` (ruta de cuentas) y un `dependent_user_id` que se ignora.
      app.push.handleNotificationTapForTesting(
        RemoteMessage(data: {
          'route': '/class/3',
          'dependent_user_id': 'someone-else',
        }),
      );
      expect(
        app.container.read(pendingNavigationProvider)?.route,
        RouteNames.deviceClassDetailPath(3),
        reason: 'mapped to the device class screen, no profile dialog',
      );

      app.gate.complete();
      await _settle(tester);

      expect(location(app.router), RouteNames.deviceClassDetailPath(3));
      expect(app.container.read(pendingNavigationProvider), isNull);
    });

    testWidgets('a push with no device destination opens the notices tab',
        (tester) async {
      final app = await pumpApp(tester, deviceUser());

      app.push.handleNotificationTapForTesting(
        RemoteMessage(data: {'route': RouteNames.family}),
      );
      expect(
        app.container.read(pendingNavigationProvider)?.route,
        RouteNames.deviceInbox,
      );

      app.gate.complete();
      await _settle(tester);

      expect(location(app.router), RouteNames.deviceInbox);
    });

    testWidgets(
        'a family push with a child id opens the notices, no profile dialog',
        (tester) async {
      final app = await pumpApp(tester, deviceUser());

      for (final type in [
        'family:security',
        'dependent_age_milestone',
        'teen_guardian_reminder',
      ]) {
        app.push.handleNotificationTapForTesting(
          RemoteMessage(data: {
            'type': type,
            'dependent_user_id': 'someone-else',
          }),
        );
        expect(
          app.container.read(pendingNavigationProvider)?.route,
          RouteNames.deviceInbox,
          reason: type,
        );
        app.container.read(pendingNavigationProvider.notifier).state = null;
      }
      app.container.read(pendingNavigationProvider.notifier).state =
          PendingNavigation(
        route: RouteNames.familyDetailPath('someone-else'),
      );

      app.gate.complete();
      await _settle(tester);

      expect(location(app.router), RouteNames.deviceHome,
          reason: 'Mi familia never opens on a linked phone');
      expect(find.text('Cambiar'), findsNothing);
    });

    testWidgets('a destination outside the allowlist is dropped, not opened',
        (tester) async {
      final app = await pumpApp(tester, deviceUser());

      app.container.read(pendingNavigationProvider.notifier).state =
          const PendingNavigation(route: RouteNames.family);
      app.gate.complete();
      await _settle(tester);

      expect(app.container.read(pendingNavigationProvider), isNull);
      expect(location(app.router), RouteNames.deviceHome);
    });
  });

  group('REAL router + REAL registry: leaving device mode', () {
    testWidgets('losing the session purges every profile-scoped provider',
        (tester) async {
      final app = await pumpApp(
        tester,
        deviceUser(),
        withGate: false,
        withSentinel: true,
      );
      app.container.listen(_sentinel, (_, __) {});
      app.router.go(RouteNames.deviceHome);
      await _settle(tester);
      final before = _sentinelBuilds;
      // Un enlace sin canjear tampoco sobrevive a la sesión.
      app.container.read(pairingLinkProvider.notifier).state = 'LINK';

      // El tutor desvincula: la sesión termina y el router purga el registro.
      app.auth.emit(null);
      await _settle(tester);

      app.container.read(_sentinel);
      expect(app.container.read(pairingLinkProvider), isNull);
      expect(_sentinelBuilds, greaterThan(before),
          reason: 'the device profile cache did not survive the logout');
      // Ya sin sesión, el login de cuentas no hereda nada del niño.
      expect(app.container.read(authNotifierProvider).valueOrNull, isNull);
      expect(location(app.router), isNot(RouteNames.deviceHome));
    });
  });
}
