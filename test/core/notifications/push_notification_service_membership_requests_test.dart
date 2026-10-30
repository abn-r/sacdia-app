import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this.user);

  final UserEntity user;
  final switchCalls = <String>[];

  @override
  Future<UserEntity?> build() async => user;

  @override
  Future<bool> switchContext(String assignmentId) async {
    switchCalls.add(assignmentId);
    return true;
  }
}

UserEntity _userWithSections() => const UserEntity(
      id: 'u-1',
      email: 'a@b.c',
      name: 'Laura',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(
        effectivePermissions: ['club_members:approve'],
        activeAssignmentId: 'a-1',
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'a-1',
            permissions: ['club_members:approve'],
            clubId: 1,
            sectionId: 166,
          ),
          AuthorizationGrant(
            assignmentId: 'a-2',
            permissions: ['club_members:approve'],
            clubId: 1,
            sectionId: 167,
          ),
        ],
      ),
    );

UserEntity _userWith(List<String> permissions) => UserEntity(
      id: 'u-1',
      email: 'a@b.c',
      name: 'Laura',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(effectivePermissions: permissions),
    );

void main() {
  group('PushNotificationService membership requests', () {
    late GlobalKey<NavigatorState> navigatorKey;
    late List<String> visited;
    late _FakeAuth auth;

    setUp(() {
      navigatorKey = GlobalKey<NavigatorState>();
      visited = [];
    });

    Future<PushNotificationService> pumpApp(
      WidgetTester tester,
      UserEntity user,
    ) async {
      auth = _FakeAuth(user);
      final container = ProviderContainer(
        overrides: [authNotifierProvider.overrideWith(() => auth)],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.future);
      final service = container.read(
        Provider<PushNotificationService>(
          (ref) => PushNotificationService(
            dio: Dio(),
            ref: ref,
            navigatorKey: navigatorKey,
          ),
        ),
      );

      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            pageBuilder: (context, state) => MaterialPage<void>(
              key: state.pageKey,
              child: const Scaffold(body: Text('start')),
            ),
          ),
          GoRoute(
            path: RouteNames.homeMembers,
            pageBuilder: (context, state) {
              visited.add(state.uri.toString());
              return MaterialPage<void>(
                key: state.pageKey,
                child: Scaffold(body: Text('screen ${state.uri}')),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      return service;
    }

    final message = RemoteMessage(
      data: const {
        'type': 'membership_request_created',
        'userId': 'u-9',
        'assignmentId': 'a-1',
        'clubSectionId': '167',
      },
    );

    testWidgets('a reviewer lands on Members > Solicitudes', (tester) async {
      final service =
          await pumpApp(tester, _userWith(['club_members:approve']));

      service.handleNotificationTapForTesting(message);
      await tester.pumpAndSettle();

      expect(visited, [RouteNames.homeMemberRequests]);
    });

    testWidgets('a user who cannot see requests gets no destination',
        (tester) async {
      final service = await pumpApp(tester, _userWith(['club_members:read']));

      service.handleNotificationTapForTesting(message);
      await tester.pumpAndSettle();

      expect(visited, isEmpty);
      expect(find.text('start'), findsOneWidget);
    });

    RemoteMessage messageFor(Object? sectionId) => RemoteMessage(
          data: {
            'type': 'membership_request_created',
            'userId': 'u-9',
            'assignmentId': 'a-1',
            if (sectionId != null) 'clubSectionId': '$sectionId',
          },
        );

    testWidgets('a push of another granted section switches context first',
        (tester) async {
      final service = await pumpApp(tester, _userWithSections());

      service.handleNotificationTapForTesting(messageFor(167));
      await tester.pumpAndSettle();

      expect(auth.switchCalls, ['a-2']);
      expect(visited, [RouteNames.homeMemberRequests]);
    });

    testWidgets('a push of the active section does not switch', (tester) async {
      final service = await pumpApp(tester, _userWithSections());

      service.handleNotificationTapForTesting(messageFor(166));
      await tester.pumpAndSettle();

      expect(auth.switchCalls, isEmpty);
      expect(visited, [RouteNames.homeMemberRequests]);
    });

    testWidgets('a push of a section without grant does not switch',
        (tester) async {
      final service = await pumpApp(tester, _userWithSections());

      service.handleNotificationTapForTesting(messageFor(999));
      await tester.pumpAndSettle();

      expect(auth.switchCalls, isEmpty);
      expect(visited, [RouteNames.homeMemberRequests]);
    });

    testWidgets('a push without clubSectionId keeps the current context',
        (tester) async {
      final service = await pumpApp(tester, _userWithSections());

      service.handleNotificationTapForTesting(messageFor(null));
      await tester.pumpAndSettle();

      expect(auth.switchCalls, isEmpty);
      expect(visited, [RouteNames.homeMemberRequests]);
    });
  });
}
