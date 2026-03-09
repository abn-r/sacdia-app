import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProviderScope boots a minimal app shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('SACDIA smoke'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('SACDIA smoke'), findsOneWidget);
  });
}
