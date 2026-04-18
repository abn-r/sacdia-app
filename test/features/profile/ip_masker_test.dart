import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/ip_masker.dart';

void main() {
  group('maskIpAddress', () {
    group('IPv4', () {
      test('masks last octet', () {
        expect(maskIpAddress('192.168.1.42'), '192.168.1.xxx');
      });

      test('masks last octet for public IP', () {
        expect(maskIpAddress('203.0.113.99'), '203.0.113.xxx');
      });

      test('masks last octet when it is 0', () {
        expect(maskIpAddress('10.0.0.0'), '10.0.0.xxx');
      });
    });

    group('IPv6', () {
      test('masks last group — full address', () {
        expect(maskIpAddress('2001:db8:0:0:1:2:3:4'), '2001:db8:0:0:1:2:3:xxxx');
      });

      test('masks last group — compressed address', () {
        expect(maskIpAddress('2001:db8::1:2:3:4'), '2001:db8::1:2:3:xxxx');
      });

      test('masks last group — loopback-like', () {
        expect(maskIpAddress('::1'), '::xxxx');
      });
    });

    group('edge cases', () {
      test('null returns IP desconocida', () {
        expect(maskIpAddress(null), 'IP desconocida');
      });

      test('empty string returns IP desconocida', () {
        expect(maskIpAddress(''), 'IP desconocida');
      });

      test('unrecognized format returns IP desconocida', () {
        expect(maskIpAddress('not-an-ip'), 'IP desconocida');
      });
    });
  });
}
