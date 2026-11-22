import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_batch.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_item.dart';
import 'package:sacdia_app/features/certificate_import/presentation/utils/import_batch_state.dart';

CertificateImportItem _row(
  String id,
  CertificateImportItemStatus status, {
  String? reason,
  bool active = true,
}) =>
    CertificateImportItem(
      id: id,
      type: CertificateImportItemType.honor,
      status: status,
      rejectionReason: reason,
      active: active,
    );

CertificateImportBatch _batch(
  List<CertificateImportItem> items, {
  String status = 'SUBMITTED',
}) =>
    CertificateImportBatch(id: 'b', status: status, items: items);

void main() {
  group('ImportBatchState.of', () {
    test('rows sent and waiting read as in review', () {
      final state = ImportBatchState.of(_batch([
        _row('a', CertificateImportItemStatus.submitted),
        _row('b', CertificateImportItemStatus.resubmitted),
      ]));
      expect(state.kind, ImportBatchStateKind.inReview);
      expect(state.toFixCount, 0);
      expect(state.groups.inReview.map((i) => i.id), ['a', 'b']);
    });

    test('any rejected row makes it "por corregir", with the count', () {
      final state = ImportBatchState.of(_batch([
        _row('a', CertificateImportItemStatus.approved),
        _row('b', CertificateImportItemStatus.rejected, reason: 'x'),
        _row('c', CertificateImportItemStatus.rejected, reason: 'y'),
        _row('d', CertificateImportItemStatus.submitted),
      ]));
      expect(state.kind, ImportBatchStateKind.corrections);
      expect(state.toFixCount, 2);
      expect(state.approvedCount, 1);
      expect(state.total, 4);
    });

    test('a reason on a row not yet decided still asks for a fix', () {
      final state = ImportBatchState.of(_batch([
        _row('a', CertificateImportItemStatus.needsReview, reason: 'x'),
      ]));
      expect(state.kind, ImportBatchStateKind.corrections);
    });

    test('a resent row with a leftover reason is not a fix', () {
      final state = ImportBatchState.of(_batch([
        _row('a', CertificateImportItemStatus.resubmitted, reason: 'old'),
      ]));
      expect(state.kind, ImportBatchStateKind.inReview);
    });

    test('some approved and the rest waiting is approved in part', () {
      final state = ImportBatchState.of(_batch([
        _row('a', CertificateImportItemStatus.approved),
        _row('b', CertificateImportItemStatus.submitted),
      ]));
      expect(state.kind, ImportBatchStateKind.partial);
    });

    test('every row approved is approved', () {
      final state = ImportBatchState.of(_batch([
        _row('a', CertificateImportItemStatus.approved),
        _row('b', CertificateImportItemStatus.approved),
      ]));
      expect(state.kind, ImportBatchStateKind.approved);
    });

    test('removed rows are ignored', () {
      final state = ImportBatchState.of(_batch([
        _row('a', CertificateImportItemStatus.approved),
        _row('r', CertificateImportItemStatus.rejected,
            reason: 'x', active: false),
      ]));
      expect(state.kind, ImportBatchStateKind.approved);
      expect(state.total, 1);
    });

    test('without rows the batch status decides', () {
      expect(ImportBatchState.of(_batch(const [], status: 'APPROVED')).kind,
          ImportBatchStateKind.approved);
      expect(
          ImportBatchState.of(_batch(const [], status: 'PARTIALLY_APPROVED'))
              .kind,
          ImportBatchStateKind.partial);
      expect(ImportBatchState.of(_batch(const [], status: 'SUBMITTED')).kind,
          ImportBatchStateKind.inReview);
    });
  });
}
