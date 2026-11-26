import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';

void main() {
  group('supervisionZoneCity', () {
    test('reads the place of a zone id', () {
      expect(supervisionZoneCity('America/Mexico_City'), 'Mexico City');
      expect(supervisionZoneCity('Europe/Madrid'), 'Madrid');
    });

    test('takes the last part of a nested zone id', () {
      expect(
        supervisionZoneCity('America/Argentina/Buenos_Aires'),
        'Buenos Aires',
      );
    });

    test('keeps an id with no region and trims it', () {
      expect(supervisionZoneCity(' UTC '), 'UTC');
      expect(supervisionZoneCity(''), '');
    });
  });
}
