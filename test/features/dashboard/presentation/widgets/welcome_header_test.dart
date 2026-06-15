import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/welcome_header.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required int unreadCount,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WelcomeHeader(
            userName: 'Ana Test',
            unreadNotificationsCount: unreadCount,
            onNotificationsTap: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows unread notification badge when count is positive',
      (tester) async {
    await pumpHeader(tester, unreadCount: 7);

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('hides unread notification badge when count is zero',
      (tester) async {
    await pumpHeader(tester, unreadCount: 0);

    expect(find.text('0'), findsNothing);
  });
}
