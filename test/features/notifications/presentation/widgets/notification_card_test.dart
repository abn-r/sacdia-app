import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/presentation/widgets/notification_card.dart';

void main() {
  testWidgets('opens a detail dialog when tapping a notification',
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
}
