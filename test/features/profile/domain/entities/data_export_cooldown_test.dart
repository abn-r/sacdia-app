import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/domain/entities/data_export.dart';

DataExport _export(DataExportStatus status, DateTime createdAt) => DataExport(
      exportId: createdAt.toIso8601String(),
      status: status,
      format: 'json',
      createdAt: createdAt,
    );

/// The backend rejects a new request while a ready export created in the
/// last 24 hours exists. Failed or expired exports do not count.
void main() {
  final now = DateTime(2026, 10, 16, 12);

  test('a ready export from 2 hours ago blocks for 22 more hours', () {
    final next = nextDataExportAvailableAt(
      [_export(DataExportStatus.ready, now.subtract(const Duration(hours: 2)))],
      now: now,
    );

    expect(next, now.add(const Duration(hours: 22)));
  });

  test('uses the most recent ready export', () {
    final next = nextDataExportAvailableAt(
      [
        _export(
            DataExportStatus.ready, now.subtract(const Duration(hours: 20))),
        _export(DataExportStatus.ready, now.subtract(const Duration(hours: 1))),
      ],
      now: now,
    );

    expect(next, now.add(const Duration(hours: 23)));
  });

  test('failed exports and old ready ones do not block', () {
    final next = nextDataExportAvailableAt(
      [
        _export(
            DataExportStatus.failed, now.subtract(const Duration(hours: 1))),
        _export(
            DataExportStatus.ready, now.subtract(const Duration(hours: 25))),
      ],
      now: now,
    );

    expect(next, isNull);
  });

  test('formats the wait in hours, or minutes under an hour', () {
    expect(
        formatDataExportWait(const Duration(hours: 21, minutes: 59)), '22 h');
    expect(formatDataExportWait(const Duration(minutes: 35)), '35 min');
    expect(formatDataExportWait(const Duration(seconds: 20)), '1 min');
  });
}
