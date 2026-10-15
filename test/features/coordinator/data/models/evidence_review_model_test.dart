import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/data/models/evidence_review_model.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';

void main() {
  group('EvidenceReviewItemModel.fromJson', () {
    test('parses numeric ids from GET /evidence-review/pending', () {
      final model = EvidenceReviewItemModel.fromJson({
        'id': 412,
        'type': 'class',
        'status': 'SUBMITTED',
        'member_name': 'Ana Pérez',
        'member_is_deleted': false,
        'member_id': '6f1c2c1e-0000-4000-8000-000000000001',
        'entity_name': 'Amigo',
        'section_name': 'Completar el Curso Básico de Conquistadores',
        'entity_description': null,
        'module_name': 'Requisitos generales',
        'club_section_id': 12,
        'club_name': 'Club Orión',
        'club_section_name': 'Conquistadores',
        'file_count': 2,
        'submitted_at': '2026-10-01T15:30:00.000Z',
        'validated_at': null,
        'rejection_reason': null,
      });

      expect(model.id, '412');
      expect(model.type, EvidenceReviewType.classType);
      expect(model.status, EvidenceReviewStatus.pending);
      expect(model.memberName, 'Ana Pérez');
      expect(model.fileCount, 2);
      expect(
          model.context, 'Amigo · Completar el Curso Básico de Conquistadores');
      expect(model.clubSectionLabel, 'Club Orión · Conquistadores');
      expect(model.submittedAt, DateTime.utc(2026, 10, 1, 15, 30));
    });

    test('uses honor name as context and tolerates missing club data', () {
      final item = EvidenceReviewItemModel.fromJson({
        'id': 7,
        'type': 'honor',
        'status': 'PENDING_REVIEW',
        'member_name': 'Luis Gómez',
        'entity_name': 'Chocolate',
        'section_name': 'Chocolate',
        'file_count': 0,
        'submitted_at': '2026-10-02T10:00:00.000Z',
      }).toEntity();

      expect(item.id, '7');
      expect(item.type, EvidenceReviewType.honor);
      expect(item.context, 'Chocolate');
      expect(item.clubSectionLabel, isNull);
    });

    test('parses detail files and history with numeric ids', () {
      final model = EvidenceReviewItemModel.fromJson({
        'id': 412,
        'type': 'class',
        'status': 'SUBMITTED',
        'member_name': 'Ana Pérez',
        'file_count': 1,
        'submitted_at': '2026-10-01T15:30:00.000Z',
        'files': [
          {
            'evidence_file_id': 99,
            'file_url': 'https://cdn.example.com/a.jpg',
            'file_name': 'a.jpg',
            'file_type': 'image/jpeg',
            'uploaded_at': '2026-10-01T15:29:00.000Z',
          },
        ],
        'history': [
          {
            'id': 5,
            'action': 'SUBMITTED',
            'performed_by_name': 'Ana Pérez',
            'comment': null,
            'created_at': '2026-10-01T15:30:00.000Z',
          },
        ],
      });

      expect(model.files.single.id, '99');
      expect(model.files.single.url, 'https://cdn.example.com/a.jpg');
      expect(model.files.single.name, 'a.jpg');
      expect(model.files.single.mimeType, 'image/jpeg');
      expect(model.history.single.id, '5');
      expect(model.history.single.actorName, 'Ana Pérez');
    });
  });
}
