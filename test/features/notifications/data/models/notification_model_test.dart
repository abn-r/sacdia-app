import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/notifications/data/models/notification_model.dart';

void main() {
  test('preserves notification source for visual categorization', () {
    final model = NotificationModel.fromJson({
      'log_id': 7,
      'title': 'Clase lista para revisar',
      'body': 'Un miembro completó una clase y espera revisión',
      'type': 'SECTION_ROLE',
      'target_type': 'section_role',
      'source': 'validation:class_submitted',
      'sent_by': 'system',
      'tokens_sent': 1,
      'tokens_failed': 0,
      'created_at': '2026-06-29T18:30:00.000Z',
    });

    expect(model.source, 'validation:class_submitted');
    expect(model.toJson()['source'], 'validation:class_submitted');
    expect(model.toEntity().source, 'validation:class_submitted');
  });
}
