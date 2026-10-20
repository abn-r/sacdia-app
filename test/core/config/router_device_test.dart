import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/device_pair_link.dart';
import 'package:sacdia_app/core/config/pending_navigation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_notice_provider.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserEntity _device({
  bool postRegisterComplete = true,
  bool legalPending = false,
}) =>
    UserEntity(
      id: 'kid-1',
      name: 'Ana',
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: legalPending,
      principal: const PrincipalInfo(
        kind: PrincipalKind.linkedDevice,
        device: DeviceInfo(linkedDeviceId: 'dev-1', label: 'Tablet'),
      ),
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

const _adult = UserEntity(
  id: 'adult-1',
  email: 'a@example.com',
  postRegisterComplete: true,
  principal: PrincipalInfo(kind: PrincipalKind.user),
  authorization: AuthorizationSnapshot(effectivePermissions: ['clubs:read']),
);

/// Auth que se resuelve cuando el test lo decide, para simular la carga.
class _GatedAuth extends AuthNotifier {
  _GatedAuth(this.user, {this.gate});

  final UserEntity? user;
  final Completer<void>? gate;

  @override
  Future<UserEntity?> build() async {
    if (gate != null) await gate!.future;
    return user;
  }
}

class _ReadyBootstrap extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BuildContext context;

  Future<ProviderContainer> setUpRouter(
    WidgetTester tester,
    UserEntity? user, {
    Completer<void>? gate,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox();
          },
        ),
      ),
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => _GatedAuth(user, gate: gate)),
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
      container.dispose();
    });
    if (gate == null) await container.read(authNotifierProvider.future);
    await container.read(appBootstrapProvider.future);
    return container;
  }

  Future<String?> redirectFor(
    ProviderContainer container,
    String location, {
    Uri? uri,
    String? matched,
  }) async {
    final router = container.read(routerProvider);
    final state = GoRouterState(
      router.configuration,
      uri: uri ?? Uri.parse(location),
      matchedLocation: matched ?? location,
      path: matched ?? location,
      fullPath: matched ?? location,
      pathParameters: const {},
      pageKey: ValueKey(location),
    );
    return router.configuration.topRedirect(context, state);
  }

  group('REAL router: linked device (allowlist)', () {
    testWidgets('the device shell is open', (tester) async {
      final c = await setUpRouter(tester, _device());
      for (final path in [
        RouteNames.deviceHome,
        RouteNames.deviceClasses,
        RouteNames.deviceClassDetailPath(3),
        RouteNames.deviceRequirementPath(3, 9),
        RouteNames.deviceAgenda,
        RouteNames.deviceActivityDetailPath(12),
        RouteNames.deviceInbox,
        RouteNames.notificationsInbox,
      ]) {
        expect(await redirectFor(c, path), isNull, reason: path);
      }
    });

    testWidgets('deep links to the account app all go to the device home',
        (tester) async {
      final c = await setUpRouter(tester, _device());
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeProfile,
        RouteNames.homeMembers,
        RouteNames.homeUnits,
        RouteNames.homeHonors,
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.familyLink,
        RouteNames.familyDetailPath('ana-1'),
        RouteNames.familyPairDevicePath('ana-1'),
        RouteNames.clubDetailPath('1'),
        RouteNames.activityDetailPath(4),
        RouteNames.classDetailPath('3'),
        RouteNames.postRegistration,
        RouteNames.teenPendingHome,
        RouteNames.restrictedAccount,
        RouteNames.register,
        RouteNames.forgotPassword,
        '/security/sessions',
        '/sessions',
        '/delete-account',
        '/data-export',
      ]) {
        expect(
          await redirectFor(c, path),
          RouteNames.deviceHome,
          reason: path,
        );
      }
    });

    testWidgets('/login and splash land on the device home', (tester) async {
      final c = await setUpRouter(tester, _device());
      expect(await redirectFor(c, RouteNames.login), RouteNames.deviceHome);
      expect(await redirectFor(c, RouteNames.welcome), RouteNames.deviceHome);
      expect(await redirectFor(c, RouteNames.splash), RouteNames.deviceHome);
    });

    testWidgets('an already paired device has nothing to pair', (tester) async {
      final c = await setUpRouter(tester, _device());
      expect(
        await redirectFor(c, RouteNames.devicePair),
        RouteNames.deviceHome,
      );
    });

    testWidgets('a pending-terms device sees the blocking screen on any route',
        (tester) async {
      final c = await setUpRouter(tester, _device(legalPending: true));
      for (final path in [
        RouteNames.deviceHome,
        RouteNames.deviceClasses,
        RouteNames.deviceInbox,
        RouteNames.homeDashboard,
        RouteNames.family,
        RouteNames.splash,
      ]) {
        expect(
          await redirectFor(c, path),
          RouteNames.deviceLegalBlock,
          reason: path,
        );
      }
      expect(await redirectFor(c, RouteNames.deviceLegalBlock), isNull);
      // La aceptación de cuentas NO es para el teléfono.
      expect(
        await redirectFor(c, RouteNames.legalAcceptance),
        RouteNames.deviceLegalBlock,
      );
    });

    testWidgets('an incomplete registration never reaches post-registration',
        (tester) async {
      final c = await setUpRouter(tester, _device(postRegisterComplete: false));
      expect(await redirectFor(c, RouteNames.splash),
          RouteNames.deviceRegistrationPending);
      expect(await redirectFor(c, RouteNames.deviceHome),
          RouteNames.deviceRegistrationPending);
      expect(await redirectFor(c, RouteNames.postRegistration),
          RouteNames.deviceRegistrationPending);
      expect(
          await redirectFor(c, RouteNames.deviceRegistrationPending), isNull);
    });

    testWidgets('a completed registration cannot sit on the pending screen',
        (tester) async {
      final c = await setUpRouter(tester, _device());
      expect(await redirectFor(c, RouteNames.deviceRegistrationPending),
          RouteNames.deviceHome);
      expect(await redirectFor(c, RouteNames.deviceLegalBlock),
          RouteNames.deviceHome);
    });

    testWidgets('a pending push or link outside the allowlist is dropped',
        (tester) async {
      expect(
        isPendingNavigationAllowed(
          user: _device(),
          route: RouteNames.family,
          acting: false,
        ),
        isFalse,
      );
      expect(
        isPendingNavigationAllowed(
          user: _device(),
          route: RouteNames.homeDashboard,
          acting: false,
        ),
        isFalse,
      );
      expect(
        isPendingNavigationAllowed(
          user: _device(),
          route: RouteNames.deviceClassDetailPath(2),
          acting: false,
        ),
        isTrue,
      );
      expect(
        isPendingNavigationAllowed(
          user: _device(legalPending: true),
          route: RouteNames.deviceClasses,
          acting: false,
        ),
        isFalse,
      );
    });
  });

  group('REAL router: accounts versus the device shell', () {
    testWidgets('an adult never reaches the device shell', (tester) async {
      final c = await setUpRouter(tester, _adult);
      for (final path in [
        RouteNames.deviceHome,
        RouteNames.deviceClasses,
        RouteNames.deviceClassDetailPath(1),
        RouteNames.deviceInbox,
      ]) {
        expect(await redirectFor(c, path), RouteNames.homeDashboard,
            reason: path);
      }
    });

    testWidgets('an adult keeps the account app', (tester) async {
      final c = await setUpRouter(tester, _adult);
      expect(await redirectFor(c, RouteNames.family), isNull);
      expect(await redirectFor(c, RouteNames.homeClasses), isNull);
    });

    testWidgets('an adult can open the pairing screen (only to be refused)',
        (tester) async {
      final c = await setUpRouter(tester, _adult);
      expect(await redirectFor(c, RouteNames.devicePair), isNull);
    });
  });

  group('REAL router: logged out', () {
    testWidgets('the pairing screen is reachable, the shell is not',
        (tester) async {
      final c = await setUpRouter(tester, null);
      expect(await redirectFor(c, RouteNames.devicePair), isNull);
      expect(await redirectFor(c, RouteNames.deviceHome), RouteNames.login);
      expect(await redirectFor(c, RouteNames.deviceClasses), RouteNames.login);
    });

    testWidgets('an unpaired phone goes back to pairing, not to the login',
        (tester) async {
      final c = await setUpRouter(tester, null);
      c.read(deviceNoticeProvider.notifier).state = DeviceNotice.unpaired;

      expect(
          await redirectFor(c, RouteNames.deviceHome), RouteNames.devicePair);
      expect(await redirectFor(c, RouteNames.login), RouteNames.devicePair);
      expect(await redirectFor(c, RouteNames.splash), RouteNames.devicePair);
      expect(await redirectFor(c, RouteNames.devicePair), isNull);

      // Descartado el aviso, el teléfono ya no es especial.
      c.read(deviceNoticeProvider.notifier).state = null;
      expect(await redirectFor(c, RouteNames.deviceHome), RouteNames.login);
    });
  });

  group('REAL router: sacdia://pair deep links', () {
    final link = Uri.parse('sacdia://pair?c=LINK_token-1');

    testWidgets('are stashed in memory and parked on splash', (tester) async {
      final c = await setUpRouter(tester, null);

      final target =
          await redirectFor(c, link.toString(), uri: link, matched: '/');

      expect(target, RouteNames.splash);
      expect(c.read(pairingLinkProvider), 'LINK_token-1');
    });

    testWidgets('then reach the pairing screen once the session settled',
        (tester) async {
      final c = await setUpRouter(tester, null);
      c.read(pairingLinkProvider.notifier).state = 'LINK_token-1';

      expect(await redirectFor(c, RouteNames.splash), RouteNames.devicePair);
      expect(await redirectFor(c, RouteNames.login), RouteNames.devicePair);
      expect(await redirectFor(c, RouteNames.welcome), RouteNames.devicePair);
    });

    testWidgets('with an account session they still reach the refusal screen',
        (tester) async {
      final c = await setUpRouter(tester, _adult);
      c.read(pairingLinkProvider.notifier).state = 'LINK_token-1';

      expect(await redirectFor(c, RouteNames.splash), RouteNames.devicePair);
    });

    testWidgets('never hijack a paired device', (tester) async {
      final c = await setUpRouter(tester, _device());
      c.read(pairingLinkProvider.notifier).state = 'LINK_token-1';

      expect(await redirectFor(c, RouteNames.splash), RouteNames.deviceHome);
    });

    testWidgets('a malformed or foreign link is ignored', (tester) async {
      final c = await setUpRouter(tester, null);
      for (final uri in [
        Uri.parse('sacdia://pair'),
        Uri.parse('sacdia://pair?c='),
        Uri.parse('sacdia://elsewhere?c=abc'),
        Uri.parse('https://sacdia.com/pair?c=abc'),
      ]) {
        await redirectFor(c, uri.toString(), uri: uri, matched: '/');
        expect(c.read(pairingLinkProvider), isNull, reason: '$uri');
      }
    });

    testWidgets('a link that arrives while the session loads is not lost',
        (tester) async {
      final gate = Completer<void>();
      final c = await setUpRouter(tester, null, gate: gate);

      // Aún cargando: el redirect lo manda a splash y lo guarda.
      expect(
        await redirectFor(c, link.toString(), uri: link, matched: '/'),
        RouteNames.splash,
      );
      expect(c.read(pairingLinkProvider), 'LINK_token-1');
      expect(await redirectFor(c, RouteNames.splash), isNull,
          reason: 'still loading: stay on splash');

      gate.complete();
      await c.read(authNotifierProvider.future);

      // Con la sesión lista, el siguiente redirect desde splash lo entrega.
      expect(await redirectFor(c, RouteNames.splash), RouteNames.devicePair);
    });
  });
}
