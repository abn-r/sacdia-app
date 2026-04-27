import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/qr/presentation/views/qr_scanner_view.dart';

void main() {
  test('maps connection errors to the generic network message', () {
    expect(
      qrScanErrorMessageKey(ConnectionException(message: 'timeout')),
      'common.error_network',
    );
  });

  test('maps functional scan errors to a safe generic scan message', () {
    expect(
      qrScanErrorMessageKey(ServerException(message: 'Forbidden', code: 403)),
      'qr.errors.scan_failed',
    );
    expect(
      qrScanErrorMessageKey(Exception('boom')),
      'qr.errors.scan_failed',
    );
  });
}
