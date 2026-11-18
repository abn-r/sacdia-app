import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/materials/presentation/utils/receipt_file_name.dart';

void main() {
  group('friendlyReceiptUploadName', () {
    test('uses comprobante-<folio>.<ext>', () {
      expect(
        friendlyReceiptUploadName(folio: 'MAT-2026-0142', extension: 'PNG'),
        'comprobante-MAT-2026-0142.png',
      );
    });

    test('drops unsafe characters and handles an empty folio', () {
      expect(
        friendlyReceiptUploadName(folio: 'a/b c', extension: '.jpg'),
        'comprobante-abc.jpg',
      );
      expect(
        friendlyReceiptUploadName(folio: '', extension: 'jpg'),
        'comprobante.jpg',
      );
    });
  });

  group('isGeneratedReceiptName', () {
    test('detects picker temp names', () {
      expect(isGeneratedReceiptName('image_picker_9A085501-1B2C.png'), isTrue);
      expect(isGeneratedReceiptName('scaled_foto.jpg'), isTrue);
      expect(
        isGeneratedReceiptName('9a085501-1b2c-4d3e-8f90-123456789abc.jpg'),
        isTrue,
      );
      expect(isGeneratedReceiptName(''), isTrue);
    });

    test('keeps real user names', () {
      expect(isGeneratedReceiptName('transferencia_bbva.pdf'), isFalse);
      expect(isGeneratedReceiptName('comprobante-MAT-1.png'), isFalse);
    });
  });

  group('receiptDisplayName', () {
    String name(String stored, int pos, int total) => receiptDisplayName(
          storedName: stored,
          defaultLabel: 'Comprobante',
          position: pos,
          total: total,
        );

    test('replaces generated names, numbering only with several receipts', () {
      expect(name('image_picker_AB.png', 1, 1), 'Comprobante');
      expect(name('image_picker_AB.png', 2, 3), 'Comprobante 2');
    });

    test('leaves real names untouched', () {
      expect(name('mi_pago.pdf', 2, 3), 'mi_pago.pdf');
    });
  });
}
