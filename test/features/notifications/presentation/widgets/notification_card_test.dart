import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/presentation/widgets/notification_card.dart';

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
      ProviderScope(
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
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
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
      ProviderScope(
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
}
