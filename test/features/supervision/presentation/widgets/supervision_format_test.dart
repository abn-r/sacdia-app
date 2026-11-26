import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';

void main() {
  group('supervisionZoneLabel', () {
    test('reads the place of a zone id', () {
      expect(supervisionZoneLabel('America/Mexico_City'), 'Mexico City');
      expect(supervisionZoneLabel('Europe/Madrid'), 'Madrid');
    });

    test('takes the last part of a nested zone id', () {
      expect(
        supervisionZoneLabel('America/Argentina/Buenos_Aires'),
        'Buenos Aires',
      );
    });

    test('keeps an id with no region and trims it', () {
      expect(supervisionZoneLabel(' UTC '), 'UTC');
      expect(supervisionZoneLabel(''), '');
    });
  });
}
