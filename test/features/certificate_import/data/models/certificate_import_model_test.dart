import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_batch_model.dart';

void main() {
  group('CertificateImportBatchModel', () {
    test('parses a batch with mixed honor and class rows', () {
      final model = CertificateImportBatchModel.fromJson({
        'batch_id': 'batch-1',
        'status': 'SUBMITTED',
        'local_field_id': 7,
        'files': [
          {
            'file_id': 'file-1',
            'file_url': 'https://cdn.sacdia.app/cert.jpg',
            'file_name': 'cert.jpg',
            'file_type': 'image/jpeg',
            'uploaded_at': '2026-04-12T12:00:00.000Z',
          },
        ],
        'items': [
          {
            'item_id': 'item-1',
            'item_type': 'HONOR',
            'honor_id': 10,
            'detected_name': 'Primeros Auxilios',
            'completed_at': '2026-04-12',
            'status': 'READY',
            'ocr_confidence': 0.82,
          },
          {
            'item_id': 'item-2',
            'item_type': 'CLASS',
            'class_id': 4,
            'detected_name': 'Amigo',
            'completed_at': '2026-04-12',
            'status': 'NEEDS_REVIEW',
          },
        ],
      });

      expect(model.id, 'batch-1');
      expect(model.items, hasLength(2));
      expect(model.items.first.type, CertificateImportItemType.honor);
      expect(model.items.last.type, CertificateImportItemType.clazz);
      expect(model.files.single.url, 'https://cdn.sacdia.app/cert.jpg');
      expect(model.readyCount, 1);
      expect(model.needsReviewCount, 1);
    });
  });
}
