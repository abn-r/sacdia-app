import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/support/domain/entities/faq_item.dart';

void main() {
  group('FaqItem', () {
    const item = FaqItem(
      id: 'login_forgot_password',
      category: 'account',
      question: 'Olvidé mi contraseña. ¿Cómo la recupero?',
      answer: 'Toca ¿Olvidaste tu contraseña? e ingresa tu correo.',
    );

    test('should match folded Spanish accents in the query', () {
      expect(item.matches('contrasena'), isTrue);
      expect(item.matches('CONTRASEÑA'), isTrue);
      expect(item.matches('correo'), isTrue);
    });

    test('should reject unrelated queries', () {
      expect(item.matches('camporee'), isFalse);
    });

    test('should treat blank queries as a match', () {
      expect(item.matches('   '), isTrue);
    });
  });
}
