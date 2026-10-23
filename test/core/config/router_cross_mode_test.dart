import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/auth/session_mode.dart';
import 'package:sacdia_app/core/config/device_pair_link.dart';
import 'package:sacdia_app/core/config/pending_navigation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/providers/profile_scope_registry.dart';
import 'package:sacdia_app/core/storage/json_file_cache.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/acting_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/profile_scope_purge.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_connectivity_provider.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/qr/domain/entities/qr_member_token.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';
import 'package:sacdia_app/providers/json_file_cache_provider.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/device_mode/device_test_harness.dart';
import '../../features/family/family_test_harness.dart';

/// Lo que cada modo «cachea» en memoria: un centinela del registro de perfil.
/// Si la purga de cierre de sesión lo respeta, el modo siguiente lo ve vacío.
final _cache = StateProvider<String?>((ref) => null);

UserEntity _adult() => const UserEntity(
      id: 'adult-1',
      email: 'maria@example.com',
      postRegisterComplete: true,
      principal: PrincipalInfo(kind: PrincipalKind.user),
      authorization:
          AuthorizationSnapshot(effectivePermissions: ['clubs:read']),
    );

UserEntity _actingAs() => const UserEntity(
      id: 'ana-1',
      email: 'ana@example.com',
      postRegisterComplete: true,
      principal: PrincipalInfo(kind: PrincipalKind.guardianActing),
      authorization:
          AuthorizationSnapshot(effectivePermissions: ['clubs:read']),
    );

UserEntity _teen({required bool pending}) => UserEntity(
      id: 'teen-1',
      email: 'teen@example.com',
      postRegisterComplete: true,
      serverMode:
          pending ? AccountMode.teenPending : AccountMode.teenSupervised,
      principal: PrincipalInfo(
        kind: PrincipalKind.supervisedUser,
        supervision: SupervisionInfo(
          status: pending
              ? SupervisionStatus.pendingGuardian
              : SupervisionStatus.active,
        ),
      ),
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

class _Auth extends AuthNotifier {
  _Auth(this.user);

  UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;

  void emit(UserEntity? next) => state = AsyncValue.data(next);
}

class _ReadyBootstrap extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

class _NullDashboard extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _NullProfile extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

class _FakeQr extends QrMemberTokenNotifier {
  @override
  Future<QrMemberToken> build() async => QrMemberToken(
        token: 'QR',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        expiresIn: 3600,
      );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  setUp(() {
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

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  testWidgets(
      'account -> teen -> device -> acting through logout/login leaves no '
      'cached data behind', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = ActingForSession();
    final auth = _Auth(_adult());
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        jsonFileCacheProvider.overrideWithValue(MemoryJsonFileCache()),
        actingForSessionProvider.overrideWithValue(session),
        notificationsRepositoryProvider
            .overrideWithValue(FakeNotificationsRepository()),
        userClassesProvider.overrideWith((ref) async => const [mathClass]),
        classWithProgressProvider
            .overrideWith((ref, q) async => classWithProgress()),
        clubActivitiesProvider
            .overrideWith((ref, params) async => [activity(1)]),
        activityDetailProvider.overrideWith((ref, id) async => activity(id)),
        qrMemberTokenProvider.overrideWith(_FakeQr.new),
        deviceOnlineProvider.overrideWith((ref) => Stream.value(true)),
        profileScopedProvidersProvider
            .overrideWithValue([...profileScopedProviders, _cache]),
      ],
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
      container.dispose();
    });
    await container.read(authNotifierProvider.future);
    final router = container.read(routerProvider);
    await pumpLocalizedRouterApp(tester, container, router);

    /// Escribe en cada lugar donde un modo deja rastro en memoria.
    void leaveTraces(String who) {
      container.read(_cache.notifier).state = who;
      container.read(pendingNavigationProvider.notifier).state =
          const PendingNavigation(route: RouteNames.notificationsInbox);
      container.read(pairingLinkProvider.notifier).state = 'LINK-$who';
    }

    void expectNoTraces(String reason) {
      expect(container.read(_cache), isNull, reason: '$reason: profile cache');
      expect(container.read(pendingNavigationProvider), isNull,
          reason: '$reason: parked push');
      expect(container.read(pairingLinkProvider), isNull,
          reason: '$reason: pairing link');
      expect(session.isActing, isFalse, reason: '$reason: acting session');
      expect(container.read(guardianUserProvider), isNull,
          reason: '$reason: guardian snapshot');
    }

    Future<void> logout() async {
      auth.emit(null);
      await _settle(tester);
    }

    Future<void> login(UserEntity user) async {
      auth.emit(user);
      await _settle(tester);
    }

    // 1. Cuenta adulta.
    router.go(RouteNames.homeDashboard);
    await _settle(tester);
    expect(location(router), RouteNames.homeDashboard);
    leaveTraces('account');
    await logout();
    expectNoTraces('account -> logout');

    // 2. Adolescente sin tutor: no hereda nada de la cuenta y el push que
    // esperaba a la persona anterior no se le entrega.
    await login(_teen(pending: true));
    expect(location(router), RouteNames.teenPendingHome);
    expect(container.read(_cache), isNull, reason: 'teen starts empty');
    leaveTraces('teen');
    await logout();
    expectNoTraces('teen -> logout');

    // 3. Teléfono vinculado de un menor.
    container.read(sessionModeProvider.notifier).state = SessionMode.device;
    await login(deviceUser());
    expect(location(router), RouteNames.deviceHome);
    expect(container.read(_cache), isNull, reason: 'device starts empty');
    leaveTraces('device');
    await logout();
    expectNoTraces('device -> logout');
    container.read(sessionModeProvider.notifier).state = SessionMode.account;

    // 4. Tutor actuando por un menor: la sesión de «actuar por» y la foto del
    // tutor mueren con el cierre de sesión.
    await login(_adult());
    session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    container.read(guardianUserProvider.notifier).state = _adult();
    auth.emit(_actingAs());
    await _settle(tester);
    expect(container.read(_cache), isNull, reason: 'acting starts empty');
    leaveTraces('acting');
    await logout();
    expectNoTraces('acting -> logout');

    // 5. Y la persona siguiente (cuenta adulta otra vez) tampoco ve nada.
    await login(_teen(pending: false));
    expect(container.read(_cache), isNull, reason: 'teen with guardian');
    expect(container.read(pendingNavigationProvider), isNull);
    expect(location(router), isNot(RouteNames.notificationsInbox),
        reason: 'a parked push is never delivered to the next person');
  });
}
