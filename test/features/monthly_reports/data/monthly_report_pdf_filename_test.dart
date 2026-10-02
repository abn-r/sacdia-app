import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/monthly_reports/data/monthly_report_pdf_filename.dart';

void main() {
  const filename =
      'informe-mensual-Senderos-Conquistadores-agosto-2026.pdf';

  test('uses the Content-Disposition filename', () {
    expect(
      monthlyReportPdfFileName(
        'attachment; filename="$filename"; filename*=UTF-8\'\'$filename',
        fallback: 'informe-mensual-fallback.pdf',
      ),
      filename,
    );
  });

  test('rejects path traversal and keeps the fallback', () {
    expect(
      monthlyReportPdfFileName(
        'attachment; filename="../../secreto.pdf"',
        fallback: 'informe-mensual-fallback.pdf',
      ),
      'informe-mensual-fallback.pdf',
    );
  });
}
