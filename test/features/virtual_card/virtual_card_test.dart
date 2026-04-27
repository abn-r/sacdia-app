import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';

void main() {
  group('VirtualCard', () {
    test('detects expired and inactive states from its payload', () {
      final card = VirtualCard(
        userId: 'usr_123',
        fullName: 'Juan Pérez Martínez',
        qrToken: 'token',
        qrExpiresAt: DateTime.utc(2024, 1, 1),
        isActive: false,
      );

      expect(card.isExpired, isTrue);
      expect(card.isInactive, isTrue);
      expect(card.canShowQr, isFalse);
    });

    test('copyWith preserves payload while toggling offline state', () {
      final card = VirtualCard(
        userId: 'usr_123',
        fullName: 'Juan Pérez Martínez',
        qrToken: 'token',
        qrExpiresAt: DateTime.utc(2099, 1, 1),
        isActive: true,
      );

      final offline = card.copyWith(isOffline: true);

      expect(offline.fullName, card.fullName);
      expect(offline.qrToken, card.qrToken);
      expect(offline.isOffline, isTrue);
      expect(offline.isExpired, isFalse);
    });
  });
}
