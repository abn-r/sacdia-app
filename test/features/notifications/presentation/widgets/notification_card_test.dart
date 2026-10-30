import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/presentation/widgets/notification_card.dart';
import '../../../../support/riverpod_test_support.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this.user);

  final UserEntity? user;
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

NotificationItem _consentNotification() => NotificationItem(
      logId: 9,
      title: 'Menor · consentimiento pendiente',
      body: 'Hay una solicitud de un menor lista para revisar.',
      type: 'SECTION_ROLE',
      source: 'membership_requests:new_request',
      targetType: NotificationTargetType.sectionRole,
      targetId: '167',
      sentBy: 'system',
      tokensSent: 1,
      tokensFailed: 0,
      createdAt: DateTime(2026, 6, 1, 9),
      isRead: true,
    );

Future<_FakeAuth> _pumpConsentCard(
  WidgetTester tester,
  UserEntity user, {
  NotificationItem? notification,
}) async {
  final auth = _FakeAuth(user);
  final router = GoRouter(
    initialLocation: '/inbox',
    routes: [
      GoRoute(
        path: '/inbox',
        builder: (context, state) => Scaffold(
          body: NotificationCard(
            notification: notification ?? _consentNotification(),
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.homeDashboard,
        builder: (context, state) =>
            const Scaffold(body: Text('dashboard-screen')),
      ),
      GoRoute(
        path: RouteNames.homeMembers,
        builder: (context, state) =>
            Scaffold(body: Text('members-screen ${state.uri}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = createTestContainer(
    overrides: [authNotifierProvider.overrideWith(() => auth)],
  );
  // La sesión ya está cargada cuando se toca una notificación en la app real.
  await container.read(authNotifierProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('opens a detail sheet when tapping a notification',
      (tester) async {
    final notification = NotificationItem(
      logId: 1,
      title: 'Aviso importante',
      body: 'Detalle completo de la notificación para el usuario.',
      type: 'USER',
      targetType: NotificationTargetType.direct,
      sentBy: 'system',
      tokensSent: 1,
      tokensFailed: 0,
      createdAt: DateTime(2026, 6, 15, 10, 30),
      deliveryId: 'delivery-1',
      isRead: true,
      readAt: DateTime(2026, 6, 15, 10, 31),
    );

    await tester.pumpWidget(
      testProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: NotificationCard(notification: notification),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aviso importante'));
    await tester.pumpAndSettle();

    expect(
      find.text('Detalle completo de la notificación para el usuario.'),
      findsWidgets,
    );
    expect(find.text('notifications.inbox.detail_accept'), findsOneWidget);
  });

  testWidgets('monthly report notifications link to the Reportes screen',
      (tester) async {
    final notification = NotificationItem(
      logId: 2,
      title: 'El informe de mayo ya está listo',
      body: 'Ya pueden revisar el informe mensual en Reportes.',
      type: 'SECTION_ROLE',
      source: 'monthly_reports:reminder',
      targetType: NotificationTargetType.sectionRole,
      sentBy: 'system',
      tokensSent: 1,
      tokensFailed: 0,
      createdAt: DateTime(2026, 6, 1, 9),
      isRead: true,
    );

    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (context, state) => Scaffold(
            body: NotificationCard(notification: notification),
          ),
        ),
        GoRoute(
          path: RouteNames.homeReports,
          builder: (context, state) =>
              const Scaffold(body: Text('reports-screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      testProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    await tester.tap(find.text('El informe de mayo ya está listo'));
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('notification-detail-action'));
    expect(action, findsOneWidget);
    expect(find.text('notifications.inbox.detail_accept'), findsOneWidget);

    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('reports-screen'), findsOneWidget);
  });

  testWidgets('notifications without a destination only offer Aceptar',
      (tester) async {
    final notification = NotificationItem(
      logId: 3,
      title: 'Aviso general',
      body: 'Sin acción asociada.',
      type: 'USER',
      source: 'admin:manual_send',
      targetType: NotificationTargetType.direct,
      sentBy: 'system',
      tokensSent: 1,
      tokensFailed: 0,
      createdAt: DateTime(2026, 6, 1, 9),
      isRead: true,
    );

    await tester.pumpWidget(
      testProviderScope(
        child: MaterialApp(
          home: Scaffold(body: NotificationCard(notification: notification)),
        ),
      ),
    );

    await tester.tap(find.text('Aviso general'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-detail-action')),
      findsNothing,
    );
    expect(find.text('notifications.inbox.detail_accept'), findsOneWidget);
  });

  testWidgets('membership request opens Members on the requests tab',
      (tester) async {
    await _pumpConsentCard(tester, _userWith(['club_members:approve']));

    await tester.tap(find.text('Menor · consentimiento pendiente'));
    await tester.pumpAndSettle();

    expect(
      find.text('members-screen ${RouteNames.homeMemberRequests}'),
      findsOneWidget,
    );
  });

  testWidgets('membership request without access keeps the info sheet',
      (tester) async {
    await _pumpConsentCard(tester, _userWith(['club_members:read']));

    await tester.tap(find.text('Menor · consentimiento pendiente'));
    await tester.pumpAndSettle();

    expect(find.textContaining('members-screen'), findsNothing);
    expect(find.text('notifications.inbox.detail_accept'), findsOneWidget);
  });

  testWidgets('membership request of another granted section switches first',
      (tester) async {
    // `_consentNotification` apunta a la sección 167; el contexto activo es la
    // 166.
    final auth = await _pumpConsentCard(tester, _userWithSections());

    await tester.tap(find.text('Menor · consentimiento pendiente'));
    await tester.pumpAndSettle();

    expect(auth.switchCalls, ['a-2']);
    expect(
      find.text('members-screen ${RouteNames.homeMemberRequests}'),
      findsOneWidget,
    );
  });

  testWidgets('membership request of a section without grant does not switch',
      (tester) async {
    final auth = await _pumpConsentCard(
      tester,
      _userWithSections(),
      notification: _consentNotification().copyWith(targetId: '999'),
    );

    await tester.tap(find.text('Menor · consentimiento pendiente'));
    await tester.pumpAndSettle();

    expect(auth.switchCalls, isEmpty);
    expect(
      find.text('members-screen ${RouteNames.homeMemberRequests}'),
      findsOneWidget,
    );
  });

  testWidgets('membership request without target_id (old server) keeps going',
      (tester) async {
    final auth = await _pumpConsentCard(
      tester,
      _userWithSections(),
      notification: NotificationItem(
        logId: 10,
        title: 'Solicitud sin sección',
        body: 'Servidor anterior.',
        type: 'SECTION_ROLE',
        source: 'membership_requests:new_request',
        targetType: NotificationTargetType.sectionRole,
        sentBy: 'system',
        tokensSent: 1,
        tokensFailed: 0,
        createdAt: DateTime(2026, 6, 1, 9),
        isRead: true,
      ),
    );

    await tester.tap(find.text('Solicitud sin sección'));
    await tester.pumpAndSettle();

    expect(auth.switchCalls, isEmpty);
    expect(
      find.text('members-screen ${RouteNames.homeMemberRequests}'),
      findsOneWidget,
    );
  });
}
