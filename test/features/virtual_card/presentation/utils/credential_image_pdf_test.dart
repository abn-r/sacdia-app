import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/presentation/utils/credential_image_pdf.dart';

void main() {
  test('builds a valid PDF from a credential PNG image', () async {
    final pngBytes = await File('assets/img/LogoSACDIA.png').readAsBytes();

    final pdfBytes = await buildCredentialImagePdf(pngBytes);

    expect(pdfBytes.length, greaterThan(100));
    expect(pdfBytes.take(4).toList(), equals(<int>[0x25, 0x50, 0x44, 0x46]));
  });
}
