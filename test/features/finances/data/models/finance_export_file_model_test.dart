import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/finances/data/models/finance_export_file_model.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_export.dart';

String _name(String? header,
        {FinanceExportFormat format = FinanceExportFormat.pdf}) =>
    FinanceExportFileModel.resolveFileName(
      header,
      year: 2026,
      month: 9,
      format: format,
    );

void main() {
  group('resolveFileName', () {
    test('reads a quoted filename', () {
      expect(
        _name('attachment; filename="finanzas-club-central-2026-09.pdf"'),
        'finanzas-club-central-2026-09.pdf',
      );
    });

    test('reads an unquoted filename and an RFC 5987 filename*', () {
      expect(_name('attachment; filename=finanzas-2026-09.pdf'),
          'finanzas-2026-09.pdf');
      expect(
        _name("attachment; filename*=UTF-8''finanzas-pe%C3%B1a-2026-09.pdf"),
        'finanzas-pe_a-2026-09.pdf',
      );
    });

    test('falls back without a header', () {
      expect(_name(null), 'finanzas-2026-09.pdf');
      expect(_name('  '), 'finanzas-2026-09.pdf');
      expect(_name('attachment'), 'finanzas-2026-09.pdf');
      expect(
        _name(null, format: FinanceExportFormat.xlsx),
        'finanzas-2026-09.xlsx',
      );
    });

    test('drops paths so the file stays inside the temp directory', () {
      expect(_name('attachment; filename="../../etc/x-2026-09.pdf"'),
          'x-2026-09.pdf');
      expect(_name(r'attachment; filename="..\..\x-2026-09.pdf"'),
          'x-2026-09.pdf');
      expect(_name('attachment; filename=".pdf"'), 'finanzas-2026-09.pdf');
    });

    test('does not trust an extension that is not the requested format', () {
      expect(
          _name('attachment; filename="finanzas.exe"'), 'finanzas-2026-09.pdf');
      expect(
        _name(
          'attachment; filename="finanzas.pdf"',
          format: FinanceExportFormat.xlsx,
        ),
        'finanzas-2026-09.xlsx',
      );
    });
  });
}
