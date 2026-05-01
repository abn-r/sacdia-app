import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/qr/data/models/qr_scan_result_model.dart';

Map<String, dynamic> _payload({
  bool includeValid = true,
  bool includeAttendance = true,
}) {
  return {
    if (includeValid) 'valid': true,
    'member': {
      'user_id': 'user-123',
      'full_name': 'Ana Lopez',
      'avatar': null,
      'club_name': 'Club Orion',
      'section_name': 'Unidad Pioneros',
    },
    if (includeAttendance)
      'attendance': {
        'registered': true,
        'already_present': false,
        'activity_id': 88,
      },
    'scanned_at': '2026-04-23T18:42:00.000Z',
  };
}

void main() {
  test('accepts the canonical validate payload', () {
    final result = QrScanResultModel.fromJson(_payload());

    expect(result.member.fullName, 'Ana Lopez');
    expect(result.member.clubName, 'Club Orion');
    expect(result.attendance?.registered, isTrue);
    expect(result.scannedAt, DateTime.utc(2026, 4, 23, 18, 42));
  });

  test('keeps backward compatibility when valid is omitted', () {
    final result = QrScanResultModel.fromJson(
      _payload(includeValid: false, includeAttendance: false),
    );

    expect(result.member.sectionName, 'Unidad Pioneros');
    expect(result.attendance, isNull);
    expect(result.scannedAt, DateTime.utc(2026, 4, 23, 18, 42));
  });
}
