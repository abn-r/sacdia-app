import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/investiture/domain/entities/investiture_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InvestitureStatus', () {
    test('parses EXPIRED from backend after trimming whitespace', () {
      final status = InvestitureStatus.fromString(' expired ');

      expect(status, InvestitureStatus.expired);
      expect(status.backendValue, 'EXPIRED');
    });

    test('defines expired status label in translation assets', () async {
      final raw = await rootBundle.loadString('assets/translations/es.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final investiture = json['investiture'] as Map<String, dynamic>;
      final status = investiture['status'] as Map<String, dynamic>;

      expect(status['expired'], 'Vencida');
    });
  });
}
