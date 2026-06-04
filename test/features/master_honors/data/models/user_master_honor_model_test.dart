import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/master_honors/data/models/user_master_honor_model.dart';

void main() {
  group('UserMasterHonorModel', () {
    test('parses no-current master honor payload from backend', () {
      final model = UserMasterHonorModel.fromJson({
        'user_master_honor_id': 10,
        'master_honor_id': 2,
        'name': 'Maestría en Acuática',
        'master_image': 'https://example.com/a.png',
        'status': 'REVOKED',
        'is_current': false,
        'display_status_label': 'No vigente',
        'awarded_at': '2026-06-03T10:00:00Z',
      });

      expect(model.userMasterHonorId, 10);
      expect(model.masterHonorId, 2);
      expect(model.name, 'Maestría en Acuática');
      expect(model.masterImage, 'https://example.com/a.png');
      expect(model.status, 'REVOKED');
      expect(model.isCurrent, isFalse);
      expect(model.displayStatusLabel, 'No vigente');
      expect(model.awardedAt, DateTime.parse('2026-06-03T10:00:00Z'));
      expect(model.revokedAt, isNull);
      expect(model.recoveredAt, isNull);
      expect(model.statusReason, isNull);
    });

    test('maps to domain entity without losing status fields', () {
      final entity = UserMasterHonorModel.fromJson({
        'user_master_honor_id': 10,
        'master_honor_id': 2,
        'name': 'Maestría en Acuática',
        'status': 'AWARDED',
        'is_current': true,
        'display_status_label': 'Vigente',
      }).toEntity();

      expect(entity.userMasterHonorId, 10);
      expect(entity.masterHonorId, 2);
      expect(entity.isCurrent, isTrue);
      expect(entity.displayStatusLabel, 'Vigente');
    });
  });
}
