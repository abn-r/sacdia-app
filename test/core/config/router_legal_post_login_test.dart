import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart';

/// What the sign-in endpoints return: a session user WITHOUT the
/// authorization snapshot or the legal status (those only come from
/// `/auth/me`). This is what forces the bootstrap retry path to refetch.
const _signedInUser = UserEntity(
  id: 'u1',
  email: 'u1@example.com',
  name: 'Elena',
);

/// What `/auth/me` returns afterwards: full authorization and
/// `legal.requires_acceptance == true`.
const _meUser = UserEntity(
  id: 'u1',
  email: 'u1@example.com',
  name: 'Elena',
  legalAcceptancePending: true,
  authorization: AuthorizationSnapshot(
    effectivePermissions: ['clubs:read'],
    globalGrants: [AuthorizationGrant(roleName: 'member')],
  ),
);

class _LoginRepository extends FakeAuthRepository {
  bool hasToken = false;
  int meCalls = 0;

  @override
  Future<bool> hasLocalToken() async => hasToken;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    meCalls++;
    return const Right(_meUser);
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    hasToken = true;
    return const Right(_signedInUser);
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    hasToken = true;
    return const Right(_signedInUser);
  }
}

void main() {
  late BuildContext context;

  Future<
      ({
        ProviderContainer container,
        _LoginRepository repo,
      })> setUpSignedOutApp(WidgetTester tester) async {
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
    final repo = _LoginRepository();
    final container = await buildAuthContainer(repo: repo);
    addTearDown(() {
      container.read(routerProvider).dispose();
      container.dispose();
    });
    // Keep the real bootstrap alive so it reacts to the auth change.
    container.listen(appBootstrapProvider, (_, __) {});
    final user = await container.read(authNotifierProvider.future);
    expect(user, isNull);
    return (container: container, repo: repo);
  }

  Future<void> settleBootstrap(ProviderContainer container) async {
    // Bootstrap invalidates itself on every auth change; wait until it
    // converges on Ready (retry loop: first attempt has no delay).
    for (var i = 0; i < 50; i++) {
      final value = container.read(appBootstrapProvider).valueOrNull;
      final auth = container.read(authNotifierProvider);
      if (value is AppBootstrapReady && !auth.isLoading) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<String?> redirectFor(ProviderContainer container, String location) {
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
    return Future.value(router.configuration.topRedirect(context, state));
  }

  testWidgets(
    'email sign-in with requires_acceptance lands on the legal gate '
    '(via the bootstrap /auth/me refetch)',
    (tester) async {
      await tester.runAsync(() async {
        final app = await setUpSignedOutApp(tester);
        final c = app.container;
        final meCallsBeforeLogin = app.repo.meCalls;

        final ok = await c
            .read(authNotifierProvider.notifier)
            .signIn(identifier: 'u1@example.com', password: 'secret');
        expect(ok, isTrue);
        // The sign-in user carries no legal status yet.
        expect(_signedInUser.legalAcceptancePending, isFalse);

        await settleBootstrap(c);

        // Bootstrap saw incomplete authorization and refetched /auth/me.
        expect(app.repo.meCalls, greaterThan(meCallsBeforeLogin));
        expect(
            c.read(appBootstrapProvider).valueOrNull, isA<AppBootstrapReady>());
        expect(
          c.read(authNotifierProvider).valueOrNull?.legalAcceptancePending,
          isTrue,
        );

        // Router lands on the gate from the login screen and the splash.
        expect(
          await redirectFor(c, RouteNames.login),
          RouteNames.legalAcceptance,
        );
        expect(
          await redirectFor(c, RouteNames.splash),
          RouteNames.legalAcceptance,
        );
        expect(await redirectFor(c, RouteNames.legalAcceptance), isNull);
      });
    },
  );

  testWidgets(
    'social sign-in with requires_acceptance lands on the legal gate',
    (tester) async {
      await tester.runAsync(() async {
        final app = await setUpSignedOutApp(tester);
        final c = app.container;
        final meCallsBeforeLogin = app.repo.meCalls;

        final result =
            await c.read(authNotifierProvider.notifier).signInWithGoogle();
        expect(result, SocialSignInResult.success);

        await settleBootstrap(c);

        expect(app.repo.meCalls, greaterThan(meCallsBeforeLogin));
        expect(
          c.read(authNotifierProvider).valueOrNull?.legalAcceptancePending,
          isTrue,
        );
        expect(
          await redirectFor(c, RouteNames.login),
          RouteNames.legalAcceptance,
        );
      });
    },
  );
}
