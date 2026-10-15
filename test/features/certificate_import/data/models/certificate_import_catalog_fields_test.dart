import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_batch_model.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_ocr_state.dart';

CertificateImportBatchModel _batch(Map<String, dynamic> extra,
        [List<Map<String, dynamic>> items = const []]) =>
    CertificateImportBatchModel.fromJson(
        {'batch_id': 'b1', 'status': 'DRAFT', 'items': items, ...extra});

Map<String, dynamic> _item(Map<String, dynamic> extra) =>
    {'item_id': 'i1', 'item_type': 'HONOR', 'status': 'READY', ...extra};

void main() {
  group('catalog blocks on items', () {
    test('reads honor, class and instructor with their names', () {
      final items = _batch({}, [
        _item({
          'honor_id': 12,
          'honor': {
            'honor_id': 12,
            'name': 'Primeros Auxilios',
            'category': {'honor_category_id': 3, 'name': 'Salud'},
          },
          'instructor': {
            'kind': 'USER',
            'user_id': 'u1',
            'display_name': 'Ana Gómez',
            'photo_url': 'https://x/p.png',
          },
        }),
        _item({
          'item_id': 'i2',
          'item_type': 'CLASS',
          'class_id': 3,
          'class': {
            'class_id': 3,
            'name': 'Explorador',
            'asset_code': 'CQ-02',
            'club_type': {'club_type_id': 1, 'name': 'Conquistadores'},
          },
          'instructor': {'kind': 'EXTERNAL', 'display_name': 'Pr. Luis'},
        }),
      ]).toEntity().items;

      expect(items[0].honor?.name, 'Primeros Auxilios');
      expect(items[0].honor?.categoryId, 3);
      expect(items[0].honor?.categoryName, 'Salud');
      expect(items[0].instructor?.isUser, isTrue);
      expect(items[0].instructor?.displayName, 'Ana Gómez');
      expect(items[0].instructor?.userId, 'u1');
      expect(items[1].classRef?.name, 'Explorador');
      expect(items[1].classRef?.assetCode, 'CQ-02');
      expect(items[1].classRef?.clubTypeId, 1);
      expect(items[1].classRef?.clubTypeName, 'Conquistadores');
      expect(items[1].classAssetCode, 'CQ-02');
      expect(items[1].instructor?.isUser, isFalse);
    });

    test('absent or null blocks mean no data (R6)', () {
      final item = _batch({}, [
        _item({'honor': null, 'class': null, 'instructor': null}),
        _item({'item_id': 'i2', 'honor': 'oops', 'instructor': {}}),
      ]).toEntity().items;
      expect(item.map((i) => i.honor), [null, null]);
      expect(item.map((i) => i.classRef), [null, null]);
      expect(item.map((i) => i.instructor), [null, null]);
    });
  });

  group('ocr_error_code on the batch', () {
    test('keeps a known code', () {
      final batch = _batch({
        'ocr_state': 'failed',
        'ocr_error_code': 'CERTIFICATE_IMPORT_PDF_ENCRYPTED',
      }).toEntity();
      expect(batch.ocrState, CertificateImportOcrState.failed);
      expect(batch.ocrErrorCode, 'CERTIFICATE_IMPORT_PDF_ENCRYPTED');
    });

    test('drops null, absent and unknown codes', () {
      expect(_batch({'ocr_error_code': null}).toEntity().ocrErrorCode, isNull);
      expect(_batch({}).toEntity().ocrErrorCode, isNull);
      expect(
          _batch({'ocr_error_code': 'SOMETHING_NEW'}).toEntity().ocrErrorCode,
          isNull);
    });
  });

  group('row completeness', () {
    CertificateImportItem row({
      CertificateImportItemType type = CertificateImportItemType.honor,
      int? honorId,
      int? classId,
      DateTime? date,
      String? name = 'Nudos',
      Map<String, dynamic>? confidence,
    }) =>
        CertificateImportItem(
          id: 'r',
          type: type,
          honorId: honorId,
          classId: classId,
          completedAt: date,
          detectedName: name,
          fieldConfidence: confidence,
          status: CertificateImportItemStatus.needsReview,
        );

    test('lists everything that is missing, in order', () {
      expect(row().missing, [
        CertificateImportMissing.honor,
        CertificateImportMissing.date,
      ]);
      expect(
        row(type: CertificateImportItemType.clazz, date: DateTime(2020))
            .missing,
        [CertificateImportMissing.clazz],
      );
      expect(row(honorId: 1, date: DateTime(2020), name: ' ').missing,
          [CertificateImportMissing.name]);
      expect(row(type: CertificateImportItemType.unknown).missing,
          [CertificateImportMissing.type]);
      expect(row(honorId: 1, date: DateTime(2020)).isComplete, isTrue);
    });

    test('date review is strictly under the 0.8 threshold', () {
      expect(row(confidence: {'date': 0.79}).needsDateReview, isTrue);
      expect(row(confidence: {'date': 0}).needsDateReview, isTrue);
      expect(row(confidence: {'date': 0.8}).needsDateReview, isFalse);
      expect(row(confidence: {'name': 0.1}).needsDateReview, isFalse);
      expect(row(confidence: {'date': '0.1'}).needsDateReview, isFalse);
      expect(row().needsDateReview, isFalse);
      expect(kDateReviewThreshold, 0.8);
    });
  });
}
