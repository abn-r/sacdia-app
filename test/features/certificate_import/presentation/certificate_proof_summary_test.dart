import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/presentation/widgets/certificate_proof_summary.dart';

void main() {
  group('CertificateProofSummary.displayName', () {
    test('hides names the phone made up', () {
      for (final name in [
        'image_picker_6F2D1A0B-9C3E-4F51-8D2A-1B7C3E9F0A12-123-0000.jpg',
        'scaled_image_picker_abc.jpg',
        '6f2d1a0b-9c3e-4f51-8d2a-1b7c3e9f0a12.jpg',
        '   ',
        '',
      ]) {
        expect(CertificateProofSummary.displayName(name), isNull, reason: name);
      }
    });

    test('keeps names the user chose', () {
      expect(
        CertificateProofSummary.displayName(' Constancia 2021.pdf '),
        'Constancia 2021.pdf',
      );
      expect(
          CertificateProofSummary.displayName('IMG_1234.JPG'), 'IMG_1234.JPG');
    });
  });
}
