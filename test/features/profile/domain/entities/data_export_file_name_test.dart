import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/domain/entities/data_export.dart';

/// The shared file needs a readable name, not the export UUID.
void main() {
  test('names the file after the export date', () {
    expect(
      dataExportFileName(DateTime(2026, 10, 16, 11, 29)),
      'sacdia-mis-datos-2026-10-16.json',
    );
  });

  test('pads single-digit months and days', () {
    expect(
      dataExportFileName(DateTime(2026, 3, 5)),
      'sacdia-mis-datos-2026-03-05.json',
    );
  });
}
