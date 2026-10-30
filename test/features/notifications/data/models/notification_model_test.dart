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

  group('target_id', () {
    Map<String, dynamic> json([Object? targetId = const _Absent()]) => {
          'log_id': 8,
          'title': 'Solicitud',
          'body': 'Nueva solicitud',
          'type': 'SECTION_ROLE',
          'target_type': 'section_role',
          'source': 'membership_requests:new_request',
          'sent_by': 'system',
          'created_at': '2026-06-29T18:30:00.000Z',
          if (targetId is! _Absent) 'target_id': targetId,
        };

    test('reaches the entity as a string', () {
      final model = NotificationModel.fromJson(json('166'));
      expect(model.toEntity().targetId, '166');
    });

    test('a numeric target_id does not break the history', () {
      final model = NotificationModel.fromJson(json(166));
      expect(model.toEntity().targetId, '166');
    });

    test('absent (older server) or null is null', () {
      expect(NotificationModel.fromJson(json()).toEntity().targetId, isNull);
      expect(
        NotificationModel.fromJson(json(null)).toEntity().targetId,
        isNull,
      );
    });
  });
}

class _Absent {
  const _Absent();
}
