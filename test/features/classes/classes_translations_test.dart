import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Classes translations', () {
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      test('defines fetch_honors and prerequisite_not_met keys for $locale',
          () async {
        final raw = await rootBundle.loadString(
          'assets/translations/$locale.json',
        );
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final errors =
            (json['classes'] as Map<String, dynamic>)['errors']
                as Map<String, dynamic>;

        expect(errors['fetch_honors'], isA<String>());
        expect((errors['fetch_honors'] as String).isNotEmpty, isTrue);
        expect(errors['prerequisite_not_met'], isA<String>());
        expect((errors['prerequisite_not_met'] as String).isNotEmpty, isTrue);
      });
    }

    test('Spanish prerequisite_not_met copy matches expected wording',
        () async {
      final raw = await rootBundle.loadString('assets/translations/es.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final errors =
          (json['classes'] as Map<String, dynamic>)['errors']
              as Map<String, dynamic>;

      expect(
        errors['prerequisite_not_met'],
        'Debes estar investido en las clases previas requeridas para inscribirte.',
      );
    });
  });
}
