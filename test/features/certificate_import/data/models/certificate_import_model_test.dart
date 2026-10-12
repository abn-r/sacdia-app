import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_batch_model.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_ocr_state.dart';

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

    group('ocr_state', () {
      CertificateImportBatchModel parse(Map<String, dynamic> extra) =>
          CertificateImportBatchModel.fromJson({
            'batch_id': 'batch-1',
            'status': 'DRAFT',
            ...extra,
          });

      test('reads every known state', () {
        for (final state in CertificateImportOcrState.values) {
          final model = parse({'ocr_state': state.name});
          expect(model.ocrState, state);
          expect(model.hasOcrState, isTrue);
          expect(model.toEntity().ocrState, state);
        }
      });

      test('an absent key means the backend does not report it', () {
        final model = parse({});
        expect(model.ocrState, isNull);
        expect(model.hasOcrState, isFalse);
      });

      test('an explicit null means OCR was never requested', () {
        final model = parse({'ocr_state': null});
        expect(model.ocrState, isNull);
        expect(model.hasOcrState, isTrue);
      });

      test('an unknown value is treated as no data', () {
        final model = parse({'ocr_state': 'recalibrating'});
        expect(model.ocrState, isNull);
        expect(model.hasOcrState, isFalse);
      });
    });
  });
}
