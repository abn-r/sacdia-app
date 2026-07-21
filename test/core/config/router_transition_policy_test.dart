import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

Iterable<GoRoute> _flattenRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
      yield* _flattenRoutes(route.routes);
    } else if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        yield* _flattenRoutes(branch.routes);
      }
    } else {
      yield* _flattenRoutes(route.routes);
    }
  }
}

GoRoute _routeByPath(GoRouter router, String path) {
  return _flattenRoutes(
    router.configuration.routes,
  ).singleWhere((route) => route.path == path);
}

CustomTransitionPage<dynamic> _buildPage(
  GoRouter router,
  GoRoute route,
  BuildContext context,
) {
  final page = route.pageBuilder!(
    context,
    GoRouterState(
      router.configuration,
      uri: Uri.parse(route.path),
      matchedLocation: route.path,
      path: route.path,
      fullPath: route.path,
      pathParameters: const {},
      pageKey: ValueKey(route.path),
    ),
  );
  return page as CustomTransitionPage<dynamic>;
}

void main() {
  testWidgets(
    'quick-access push destinations use shared-axis while shell peers keep fades',
    (tester) async {
      late BuildContext context;
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

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        ],
      );
      final router = container.read(routerProvider);

      const quickAccessDestinations = {
        RouteNames.coordinator,
        RouteNames.homeMembers,
        RouteNames.homeClub,
        RouteNames.homeEvidences,
        RouteNames.homeCamporees,
        RouteNames.homeFinances,
        RouteNames.homeUnits,
        RouteNames.homeGroupedClass,
        RouteNames.homeInsurance,
        RouteNames.homeInventory,
        RouteNames.homeMaterials,
        RouteNames.homeResources,
        RouteNames.homeReports,
        RouteNames.homeClubRankings,
      };

      for (final path in quickAccessDestinations) {
        final page = _buildPage(router, _routeByPath(router, path), context);
        final transition = page.transitionsBuilder(
          context,
          const AlwaysStoppedAnimation(0.1),
          const AlwaysStoppedAnimation(0),
          const SizedBox(),
        );

        expect(transition, isA<SlideTransition>(), reason: path);
      }

      const bottomNavigationRoots = {
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeProfile,
      };
      const dashboardPeers = {
        RouteNames.homeHonors,
        RouteNames.homeCertifications,
        RouteNames.homeAchievements,
        RouteNames.homeMasterHonors,
        RouteNames.homeMyRanking,
      };

      for (final path in {...bottomNavigationRoots, ...dashboardPeers}) {
        final page = _buildPage(router, _routeByPath(router, path), context);
        final transition = page.transitionsBuilder(
          context,
          const AlwaysStoppedAnimation(0.1),
          const AlwaysStoppedAnimation(0),
          const SizedBox(),
        );

        expect(transition, isA<FadeTransition>(), reason: path);
        expect(transition, isNot(isA<SlideTransition>()), reason: path);
      }

      router.dispose();
      container.dispose();
      await tester.pump();
    },
  );
}
