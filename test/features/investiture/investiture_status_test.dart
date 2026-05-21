import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/investiture/domain/entities/investiture_status.dart';
import 'package:sacdia_app/features/investiture/presentation/widgets/investiture_status_badge.dart';

void main() {
  group('InvestitureStatus', () {
    test('parses EXPIRED from backend', () {
      final status = InvestitureStatus.fromString('EXPIRED');

      expect(status, InvestitureStatus.expired);
      expect(status.backendValue, 'EXPIRED');
    });

    testWidgets('expired status badge renders Vencida label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvestitureStatusBadge(status: InvestitureStatus.expired),
          ),
        ),
      );

      expect(find.text('Vencida'), findsOneWidget);
    });
  });
}
