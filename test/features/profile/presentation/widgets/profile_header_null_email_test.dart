import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/profile_header.dart';

Future<void> _pump(WidgetTester tester, {String? email}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.5)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ProfileHeader(name: 'Ana Pérez', email: email),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders without crashing when the email is null',
      (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('renders the email when present', (tester) async {
    await _pump(tester, email: 'ana@example.com');

    expect(find.text('ana@example.com'), findsOneWidget);
  });
}
