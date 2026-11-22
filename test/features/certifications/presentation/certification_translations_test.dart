import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Certification translations', () {
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      test('defines module and requirement plural keys for $locale', () async {
        final raw = await rootBundle.loadString(
          'assets/translations/$locale.json',
        );
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final certifications = json['certifications'] as Map<String, dynamic>;
        final common = certifications['common'] as Map<String, dynamic>;

        for (final key in ['modules', 'requirements']) {
          final plural = common[key] as Map<String, dynamic>;
          expect(plural['one'], isNotEmpty);
          expect(plural['other'], contains('{}'));
          expect(plural['one'], isNot(plural['other']));
        }
      });
    }
  });
}
