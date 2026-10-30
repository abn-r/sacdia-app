import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../../support/riverpod_test_support.dart';

/// FP-56: la línea del `redirect` que saca de Mi familia mientras se actúa por
/// un menor (no solo la función `isBlockedWhileActing`).

const _user = UserEntity(
  id: 'u1',
  email: 'u1@example.com',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(effectivePermissions: ['clubs:read']),
);

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => _user;
}

class _ReadyBootstrap extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

void main() {
  late BuildContext context;

  Future<ProviderContainer> setUpRouter(
    WidgetTester tester, {
    required bool acting,
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
    final session = ActingForSession();
    if (acting) {
      session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    }
    final container = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
        actingForSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(() {
      container.read(routerProvider).dispose();
    });
    await container.read(authNotifierProvider.future);
    await container.read(appBootstrapProvider.future);
    return container;
  }

  Future<String?> redirectFor(
      ProviderContainer container, String location) async {
    final router = container.read(routerProvider);
    final state = GoRouterState(
      router.configuration,
      uri: Uri.parse(location),
      matchedLocation: location,
      path: location,
      fullPath: location,
      pathParameters: const {},
      pageKey: ValueKey(location),
    );
    return router.configuration.topRedirect(context, state);
  }

  final blocked = [
    RouteNames.family,
    RouteNames.familyAdd,
    RouteNames.familyLink,
    RouteNames.familyDetailPath('ana-1'),
  ];

  testWidgets('while acting every /family route redirects to home',
      (tester) async {
    final container = await setUpRouter(tester, acting: true);

    for (final path in blocked) {
      expect(
        await redirectFor(container, path),
        RouteNames.homeDashboard,
        reason: path,
      );
    }
  });

  testWidgets('while acting the rest of the app is untouched', (tester) async {
    final container = await setUpRouter(tester, acting: true);

    for (final path in [
      RouteNames.homeDashboard,
      RouteNames.homeProfile,
      RouteNames.homeClasses,
    ]) {
      expect(await redirectFor(container, path), isNull, reason: path);
    }
  });

  testWidgets('as the guardian (not acting) Mi familia opens normally',
      (tester) async {
    final container = await setUpRouter(tester, acting: false);

    for (final path in blocked) {
      expect(await redirectFor(container, path), isNull, reason: path);
    }
  });

  testWidgets('the redirect follows the session, not a snapshot',
      (tester) async {
    final container = await setUpRouter(tester, acting: false);
    expect(await redirectFor(container, RouteNames.family), isNull);

    container
        .read(actingForSessionProvider)
        .enter(const ActingDependent(userId: 'luis-1', firstName: 'Luis'));
    expect(
      await redirectFor(container, RouteNames.family),
      RouteNames.homeDashboard,
    );

    container.read(actingForSessionProvider).exit();
    expect(await redirectFor(container, RouteNames.family), isNull);
  });
}
