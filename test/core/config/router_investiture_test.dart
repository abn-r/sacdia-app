import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/authorizer_request_detail_view.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/authorizer_requests_view.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/own_investiture_view.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/section_investiture_history_view.dart';
import 'package:sacdia_app/features/investiture_requests/presentation/views/section_investiture_view.dart';

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

CustomTransitionPage<dynamic> _buildPage(
  GoRouter router,
  GoRoute route,
  BuildContext context, {
  Map<String, String> pathParameters = const {},
}) {
  final page = route.pageBuilder!(
    context,
    GoRouterState(
      router.configuration,
      uri: Uri.parse(route.path),
      matchedLocation: route.path,
      path: route.path,
      fullPath: route.path,
      pathParameters: pathParameters,
      pageKey: ValueKey(route.path),
    ),
  );
  return page as CustomTransitionPage<dynamic>;
}

void main() {
  test('investiture route names are stable and distinct', () {
    expect(RouteNames.sectionInvestiture, '/home/investiture');
    expect(RouteNames.sectionInvestitureHistory, '/home/investiture/history');
    expect(RouteNames.ownInvestiture, '/investiture/mine');
    expect(
      {
        RouteNames.sectionInvestiture,
        RouteNames.sectionInvestitureHistory,
        RouteNames.ownInvestiture,
      },
      hasLength(3),
    );
  });

  test('the authorizer routes keep the catalog path and a detail below it', () {
    // `app-investiture-authorizer` está registrada con esta ruta en el panel.
    expect(RouteNames.investitureAuthorize, '/investiture/authorize');
    expect(
      RouteNames.investitureAuthorizeDetail,
      '/investiture/authorize/:requestId',
    );
    expect(
      RouteNames.investitureAuthorizeDetailPath('abc-123'),
      '/investiture/authorize/abc-123',
    );
  });

  testWidgets('each investiture route resolves to its view', (tester) async {
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
      overrides: [authNotifierProvider.overrideWith(_FakeAuthNotifier.new)],
    );
    final router = container.read(routerProvider);
    final routes = _flattenRoutes(router.configuration.routes).toList();

    final expected = <String, Type>{
      RouteNames.sectionInvestiture: SectionInvestitureView,
      RouteNames.sectionInvestitureHistory: SectionInvestitureHistoryView,
      RouteNames.ownInvestiture: OwnInvestitureView,
      RouteNames.investitureAuthorize: AuthorizerRequestsView,
      RouteNames.investitureAuthorizeDetail: AuthorizerRequestDetailView,
    };

    for (final entry in expected.entries) {
      final route = routes.singleWhere((r) => r.path == entry.key);
      final page = _buildPage(
        router,
        route,
        context,
        pathParameters: const {'requestId': 'r-1'},
      );
      expect(page.child.runtimeType, entry.value, reason: entry.key);
      final transition = page.transitionsBuilder(
        context,
        const AlwaysStoppedAnimation(0.1),
        const AlwaysStoppedAnimation(0),
        const SizedBox(),
      );
      expect(transition, isA<SlideTransition>(), reason: entry.key);
    }

    router.dispose();
    container.dispose();
    await tester.pump();
  });
}
