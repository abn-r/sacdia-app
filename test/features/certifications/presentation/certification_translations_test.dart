import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Certification translations', () {
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      test('defines section count plural keys for $locale', () async {
        final raw = await rootBundle.loadString(
          'assets/translations/$locale.json',
        );
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final certifications = json['certifications'] as Map<String, dynamic>;
        final detail = certifications['detail'] as Map<String, dynamic>;
        final sectionsCount = detail['sections_count'] as Map<String, dynamic>;

        expect(sectionsCount['one'], contains('{count}'));
        expect(sectionsCount['other'], contains('{count}'));
        expect(sectionsCount['one'], isNot(sectionsCount['other']));
      });
    }
  });
}
