import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/data/models/virtual_card_model.dart';
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

  group('VirtualCardModel', () {
    test('maps backend /qr/me/card nested member and visual payload', () {
      final card = VirtualCardModel.fromJson({
        'token': 'qr-token',
        'expires_at': '2099-01-01T00:00:00.000Z',
        'expires_in': 300,
        'member': {
          'user_id': '104a2549-2056-4b9b-aaeb-51d8fd43191d',
          'full_name': 'Abner Reyes Ramírez',
          'avatar': 'https://example.com/avatar.png',
          'club_name': 'ACV',
          'section_name': 'Conquistadores',
        },
        'visual': {
          'title': 'SACDIA',
          'subtitle': 'Credencial digital',
          'primary_line': 'Abner Reyes Ramírez',
          'secondary_line': 'abner@example.com',
          'club_name': 'ACV',
          'section_name': 'Conquistadores',
        },
      });

      expect(card.userId, '104a2549-2056-4b9b-aaeb-51d8fd43191d');
      expect(card.fullName, 'Abner Reyes Ramírez');
      expect(card.photoUrl, 'https://example.com/avatar.png');
      expect(card.clubName, 'ACV');
      expect(card.sectionName, 'Conquistadores');
      expect(card.cardIdShort, 'fd43191d');
      expect(card.qrToken, 'qr-token');
      expect(card.canShowQr, isTrue);
    });

    test('keeps supporting legacy flat virtual card payloads', () {
      final card = VirtualCardModel.fromJson({
        'user_id': 'usr_123',
        'full_name': 'Juan Pérez Martínez',
        'photo_url': 'https://example.com/photo.png',
        'club_name': 'Central',
        'section_name': 'Guías Mayores',
        'card_id_short': 'VC-123',
        'qr_token': 'legacy-token',
        'qr_expires_at': '2099-01-01T00:00:00.000Z',
        'is_active': true,
      });

      expect(card.userId, 'usr_123');
      expect(card.fullName, 'Juan Pérez Martínez');
      expect(card.photoUrl, 'https://example.com/photo.png');
      expect(card.clubName, 'Central');
      expect(card.sectionName, 'Guías Mayores');
      expect(card.cardIdShort, 'VC-123');
      expect(card.qrToken, 'legacy-token');
    });
  });
}
