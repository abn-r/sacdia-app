import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a simple PDF wrapper around the already-rendered credential PNG.
///
/// This intentionally avoids recreating the credential UI with PDF text/fonts;
/// the on-screen card remains the single visual source of truth.
Future<Uint8List> buildCredentialImagePdf(Uint8List pngBytes) async {
  final doc = pw.Document();
  final image = pw.MemoryImage(pngBytes);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Center(
        child: pw.Image(image, fit: pw.BoxFit.contain),
      ),
    ),
  );

  return doc.save();
}
