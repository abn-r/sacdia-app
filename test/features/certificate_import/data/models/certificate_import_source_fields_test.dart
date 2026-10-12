import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/models/certificate_import_batch_model.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_file.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_proof_target.dart';

Map<String, dynamic> _file(String id,
        [Map<String, dynamic> extra = const {}]) =>
    {
      'file_id': id,
      'file_name': '$id.pdf',
      'file_type': 'application/pdf',
      ...extra
    };

Map<String, dynamic> _item(Map<String, dynamic> extra) =>
    {'item_id': 'i1', 'item_type': 'HONOR', 'status': 'READY', ...extra};

CertificateImportBatchModel _batch(
  List<Map<String, dynamic>> files,
  List<Map<String, dynamic>> items,
) =>
    CertificateImportBatchModel.fromJson(
        {'batch_id': 'b1', 'status': 'DRAFT', 'files': files, 'items': items});

void main() {
  group('optional proof fields (R6)', () {
    test('parses page_count, source_page and source_file_id when present', () {
      final batch = _batch(
        [
          _file('f1', {'page_count': 3})
        ],
        [
          _item({'source_page': 2, 'source_file_id': 'f1'})
        ],
      );
      expect(batch.files.single.pageCount, 3);
      expect(batch.items.single.sourcePage, 2);
      expect(batch.items.single.sourceFileId, 'f1');
    });

    test('missing keys give null without breaking the batch', () {
      final batch = _batch([_file('f1')], [_item({})]);
      expect(batch.files.single.pageCount, isNull);
      expect(batch.items.single.sourcePage, isNull);
      expect(batch.items.single.sourceFileId, isNull);
    });

    test('explicit null, zero, negative and junk values mean no data', () {
      final batch = _batch(
        [
          _file('f1', {'page_count': null}),
          _file('f2', {'page_count': 0})
        ],
        [
          _item({'source_page': null, 'source_file_id': null}),
          _item({'source_page': 0}),
          _item({'source_page': -1}),
          _item({'source_page': 'abc'}),
        ],
      );
      expect(batch.files.map((f) => f.pageCount), [null, null]);
      expect(batch.items.map((i) => i.sourcePage), [null, null, null, null]);
    });

    test('toJson round-trips the new fields', () {
      final batch = _batch(
        [
          _file('f1', {'page_count': 3})
        ],
        [
          _item({'source_page': 2, 'source_file_id': 'f1'})
        ],
      );
      final again = _batch(
        [batch.files.single.toJson()],
        [batch.items.single.toJson()],
      );
      expect(again.files.single.pageCount, 3);
      expect(again.items.single.sourcePage, 2);
      expect(again.items.single.sourceFileId, 'f1');
    });
  });

  group('CertificateProofTarget.resolve', () {
    const f1 = CertificateImportFile(
        id: 'f1',
        url: '',
        name: 'a.pdf',
        type: 'application/pdf',
        pageCount: 3);
    const f2 = CertificateImportFile(
        id: 'f2',
        url: '',
        name: 'b.pdf',
        type: 'application/pdf',
        pageCount: 5);
    CertificateImportItem item({int? page, String? fileId}) =>
        CertificateImportItem(
          id: 'i',
          type: CertificateImportItemType.honor,
          status: CertificateImportItemStatus.ready,
          sourcePage: page,
          sourceFileId: fileId,
        );

    test('no files gives no target', () {
      expect(CertificateProofTarget.resolve(const []), isNull);
    });

    test('opens the item file and page when both are known', () {
      final t = CertificateProofTarget.resolve(const [f1, f2],
          item: item(page: 4, fileId: 'f2'))!;
      expect((t.file.id, t.page), ('f2', 4));
    });

    test('several files without source_file_id open the first on page 1', () {
      final t =
          CertificateProofTarget.resolve(const [f1, f2], item: item(page: 2))!;
      expect((t.file.id, t.page), ('f1', 1));
    });

    test('single file keeps source_page even without source_file_id', () {
      final t =
          CertificateProofTarget.resolve(const [f1], item: item(page: 2))!;
      expect((t.file.id, t.page), ('f1', 2));
    });

    test('unknown source_file_id falls back to the first file on page 1', () {
      final t = CertificateProofTarget.resolve(const [f1, f2],
          item: item(page: 2, fileId: 'ghost'))!;
      expect((t.file.id, t.page), ('f1', 1));
    });

    test('page outside 1..page_count falls back to page 1', () {
      for (final page in [0, 4, -2]) {
        final t =
            CertificateProofTarget.resolve(const [f1], item: item(page: page))!;
        expect(t.page, 1, reason: 'page $page');
      }
    });

    test('batch without item opens the first file on page 1', () {
      final t = CertificateProofTarget.resolve(const [f1, f2])!;
      expect((t.file.id, t.page), ('f1', 1));
    });
  });
}
