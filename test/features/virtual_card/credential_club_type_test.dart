import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';
import 'package:sacdia_app/features/virtual_card/presentation/utils/credential_club_type.dart';

void main() {
  group('resolveCredentialClubType', () {
    test('should prefer Guías Mayores over the active Aventureros grant', () {
      final result = resolveCredentialClubType([
        const AuthorizationGrant(
          assignmentId: 'av',
          clubTypeName: 'Aventureros',
        ),
        const AuthorizationGrant(
          assignmentId: 'gm',
          clubTypeName: 'Guías Mayores',
        ),
      ]);

      expect(result, 'Guías Mayores');
    });

    test('should prefer Conquistadores over Aventureros', () {
      final result = resolveCredentialClubType([
        const AuthorizationGrant(
          assignmentId: 'av',
          clubTypeName: 'Aventureros',
        ),
        const AuthorizationGrant(
          assignmentId: 'cq',
          clubTypeName: 'Conquistadores',
        ),
      ]);

      expect(result, 'Conquistadores');
    });

    test('should ignore inactive grants', () {
      final result = resolveCredentialClubType([
        const AuthorizationGrant(
          assignmentId: 'gm',
          clubTypeName: 'Guías Mayores',
          status: 'expired',
        ),
        const AuthorizationGrant(
          assignmentId: 'av',
          clubTypeName: 'Aventureros',
        ),
      ]);

      expect(result, 'Aventureros');
    });

    test('should return null when no typed grants exist', () {
      expect(resolveCredentialClubType(const []), isNull);
    });
  });

  group('applyCredentialIdentity', () {
    test('should overlay identity section onto a card from another section',
        () {
      const card = VirtualCard(
        userId: 'user-1',
        fullName: 'Ana',
        qrToken: 'token',
        qrExpiresAt: null,
        isActive: true,
        sectionName: 'Aventureros',
      );

      final result = applyCredentialIdentity(
        card: card,
        assignments: const [
          AuthorizationGrant(
            assignmentId: 'av',
            clubTypeName: 'Aventureros',
          ),
          AuthorizationGrant(
            assignmentId: 'gm',
            clubTypeName: 'Guías Mayores',
          ),
        ],
      );

      expect(result.sectionName, 'Guías Mayores');
    });
  });
}
