import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_batch_model.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_item_model.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_ocr_state.dart';

void main() {
  group('CertificateImportItemModel active and revision', () {
    CertificateImportItemModel parse(Map<String, dynamic> extra) =>
        CertificateImportItemModel.fromJson({
          'item_id': 'item-1',
          'item_type': 'HONOR',
          ...extra,
        });

    test('an API without them means an active row nobody has saved', () {
      final item = parse({});
      expect(item.active, isTrue);
      expect(item.revision, 0);
    });

    test('reads a removed row and the revision', () {
      final item = parse({'active': false, 'revision': 3});
      expect(item.active, isFalse);
      expect(item.revision, 3);
      expect(item.toEntity().active, isFalse);
      expect(item.toEntity().revision, 3);
    });

    test('garbage reads as the defaults', () {
      final item = parse({'active': 'no', 'revision': -2});
      expect(item.active, isTrue);
      expect(item.revision, 0);
    });

    test('the date notice goes away once the member saved the row', () {
      final read = parse({
        'field_confidence': {'date': 0.5},
      }).toEntity();
      final saved = parse({
        'field_confidence': {'date': 0.5},
        'revision': 1,
      }).toEntity();
      expect(read.needsDateReview, isTrue);
      expect(saved.needsDateReview, isFalse);
    });

    test('a batch ignores removed rows in lists and counts', () {
      final batch = CertificateImportBatchModel.fromJson({
        'batch_id': 'b',
        'status': 'SUBMITTED',
        'items': [
          {'item_id': 'a', 'item_type': 'HONOR', 'status': 'SUBMITTED'},
          {'item_id': 'b', 'item_type': 'HONOR', 'status': 'SUBMITTED'},
          {
            'item_id': 'c',
            'item_type': 'HONOR',
            'status': 'NEEDS_REVIEW',
            'active': false,
          },
          {
            'item_id': 'd',
            'item_type': 'CLASS',
            'status': 'NEEDS_REVIEW',
            'active': false,
          },
        ],
      });
      final entity = batch.toEntity();
      expect(entity.activeItems.map((i) => i.id), ['a', 'b']);
      expect(batch.readyCount, 2);
      expect(batch.needsReviewCount, 0);
      expect(entity.needsReviewCount, 0);
    });
  });

  group('CertificateImportItemModel calendar dates', () {
    CertificateImportItemModel parse(Map<String, dynamic> extra) =>
        CertificateImportItemModel.fromJson({
          'item_id': 'item-1',
          'item_type': 'HONOR',
          ...extra,
        });

    test('reads a plain YYYY-MM-DD as that calendar day', () {
      final item = parse({'completed_at': '2021-10-15'});
      expect(item.completedAt, DateTime(2021, 10, 15));
      expect(item.completedAt!.isUtc, isFalse);
    });

    test('a UTC midnight timestamp keeps its day (negative-offset zones)', () {
      // 2021-10-15T00:00Z is 14 Oct 18:00 in America/Mexico_City; the row
      // editor must still show 15 Oct, so the value is built as a local day.
      final item = parse({
        'completed_at': '2021-10-15T00:00:00.000Z',
        'detected_date': '2024-03-12T00:00:00.000Z',
      });
      expect(item.completedAt, DateTime(2021, 10, 15));
      expect(item.detectedDate, DateTime(2024, 3, 12));
      expect(item.completedAt!.toLocal().day, 15);
      expect(item.detectedDate!.toLocal().day, 12);
    });

    test('missing or unreadable dates are null', () {
      final item = parse({'completed_at': null, 'detected_date': 'nope'});
      expect(item.completedAt, isNull);
      expect(item.detectedDate, isNull);
    });
  });

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
