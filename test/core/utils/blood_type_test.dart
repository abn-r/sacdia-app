import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/blood_type.dart';

void main() {
  group('BloodType', () {
    test('keeps compact display labels for existing profile UI', () {
      expect(BloodType.displayFor('O_POSITIVE'), 'O+');
      expect(BloodType.displayFor('AB-'), 'AB-');
    });

    test('localizes backend enum keys to readable Rh words', () {
      expect(
        BloodType.localizedDisplayFor('O_POSITIVE', languageCode: 'es'),
        'O positivo',
      );
      expect(
        BloodType.localizedDisplayFor('O_NEGATIVE', languageCode: 'en'),
        'O negative',
      );
      expect(
        BloodType.localizedDisplayFor('AB_POSITIVE', languageCode: 'fr'),
        'AB positif',
      );
      expect(
        BloodType.localizedDisplayFor('AB_NEGATIVE', languageCode: 'pt'),
        'AB negativo',
      );
    });

    test('localizes compact plus/minus values too', () {
      expect(
        BloodType.localizedDisplayFor('A+', languageCode: 'es'),
        'A positivo',
      );
      expect(
        BloodType.localizedDisplayFor('B-', languageCode: 'fr'),
        'B négatif',
      );
    });

    test('preserves unknown non-empty values as a safe fallback', () {
      expect(
        BloodType.localizedDisplayFor('SIN_DATO', languageCode: 'es'),
        'SIN_DATO',
      );
      expect(BloodType.localizedDisplayFor(null, languageCode: 'es'), isNull);
    });
  });
}
