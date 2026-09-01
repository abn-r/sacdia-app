import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_description.dart';

void main() {
  group('isRedundantCamporeeDescription', () {
    test('should hide a description that only prefixes the event name', () {
      expect(
        isRedundantCamporeeDescription(
          'Navegando con Jesús',
          'Camporee Navegando con Jesús',
        ),
        isTrue,
      );
    });

    test('should hide a description that matches the name ignoring accents',
        () {
      expect(
        isRedundantCamporeeDescription(
          'Camporí Esperanza',
          'Camporee Esperanza',
        ),
        isTrue,
      );
    });

    test('should keep a description that adds real information', () {
      expect(
        isRedundantCamporeeDescription(
          'Navegando con Jesús',
          'Llevar linterna, saco de dormir y botella de agua.',
        ),
        isFalse,
      );
    });

    test('should treat blank descriptions as redundant', () {
      expect(isRedundantCamporeeDescription('Esperanza', '   '), isTrue);
      expect(isRedundantCamporeeDescription('Esperanza', null), isTrue);
    });
  });
}
