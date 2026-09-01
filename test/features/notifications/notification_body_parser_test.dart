import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/notifications/domain/notification_body_parser.dart';

void main() {
  group('parseNotificationBody', () {
    test('keeps a winner personal message as plain prose', () {
      const body =
          'Tu constancia destacó en Conquistadores de ACV. ¡Fuiste elegido miembro del mes!';

      final parsed = parseNotificationBody(body);

      expect(parsed.hasNameList, isFalse);
      expect(parsed.raw, body);
    });

    test('keeps a single director winner as plain prose', () {
      const body = 'Mateo Hernández destacó en Conquistadores con 30 puntos';

      final parsed = parseNotificationBody(body);

      expect(parsed.hasNameList, isFalse);
    });

    test('splits a comma-separated director tie into a name list', () {
      const body =
          'Mateo Hernández, Camila García, Sebastián Martínez destacó en Conquistadores con 30 puntos';

      final parsed = parseNotificationBody(body);

      expect(parsed.hasNameList, isTrue);
      expect(parsed.names, [
        'Mateo Hernández',
        'Camila García',
        'Sebastián Martínez',
      ]);
      expect(parsed.section, 'Conquistadores');
      expect(parsed.points, 30);
    });

    test('parses newline name lists from later director copy', () {
      const body = '''
3 miembros destacaron en Aventureros con 12 puntos.

Mateo Hernández
Camila García
Sebastián Martínez
''';

      final parsed = parseNotificationBody(body);

      expect(parsed.hasNameList, isTrue);
      expect(parsed.names, [
        'Mateo Hernández',
        'Camila García',
        'Sebastián Martínez',
      ]);
      expect(parsed.section, 'Aventureros');
      expect(parsed.points, 12);
    });

    test('returns plain for empty body', () {
      expect(parseNotificationBody('').hasNameList, isFalse);
    });
  });
}
