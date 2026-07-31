import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';

void main() {
  group('AppConstants.resolveBaseUrl', () {
    test('defaults to localhost in debug without a define', () {
      expect(
        AppConstants.resolveBaseUrl(override: '', isProduct: false),
        AppConstants.localDevelopmentBaseUrl,
      );
    });

    test('allows an explicit debug URL without release validation', () {
      const value = 'http://10.0.0.5:4000/api/v1';
      expect(
        AppConstants.resolveBaseUrl(override: value, isProduct: false),
        value,
      );
    });

    test('rejects a local URL in product even if a local opt-in is injected',
        () {
      expect(
        () => AppConstants.resolveBaseUrl(
          override: AppConstants.localDevelopmentBaseUrl,
          isProduct: true,
        ),
        _throwsCode(AppConstants.releaseApiBaseUrlNotHttpsCode),
      );
    });
  });

  group('release API URL contract', () {
    const validUrl = 'https://api.sacdia.example/api/v1';

    test('accepts only its canonical HTTPS representation', () {
      expect(
        AppConstants.resolveBaseUrl(override: validUrl, isProduct: true),
        validUrl,
      );
    });

    test('uses the stable missing-value error', () {
      expect(
        () => AppConstants.resolveBaseUrl(override: '', isProduct: true),
        _throwsCode(AppConstants.releaseApiBaseUrlRequiredCode),
      );
    });

    final rejectedValues = <String, String>{
      'plain HTTP': 'http://api.sacdia.example/api/v1',
      'uppercase scheme': 'HTTPS://api.sacdia.example/api/v1',
      'localhost': 'https://localhost/api/v1',
      'localhost subdomain': 'https://api.localhost/api/v1',
      'mDNS local domain': 'https://api.sacdia.local/api/v1',
      'single-label host': 'https://intranet/api/v1',
      'invalid DNS label': 'https://_api.sacdia.example/api/v1',
      'trailing host dot': 'https://api.sacdia.example./api/v1',
      'IPv4': 'https://127.0.0.1/api/v1',
      'short IPv4 loopback': 'https://127.1/api/v1',
      'decimal IPv4': 'https://2130706433/api/v1',
      'hex IPv4': 'https://0x7f000001/api/v1',
      'octal IPv4': 'https://017700000001/api/v1',
      'private IPv4': 'https://10.0.0.1/api/v1',
      'IPv6 loopback': 'https://[::1]/api/v1',
      'expanded IPv6 loopback': 'https://[0:0:0:0:0:0:0:1]/api/v1',
      'mapped IPv4 loopback': 'https://[::ffff:127.0.0.1]/api/v1',
      'mapped hexadecimal loopback': 'https://[::ffff:7f00:1]/api/v1',
      'userinfo': 'https://user:password@api.sacdia.example/api/v1',
      'empty userinfo': 'https://@api.sacdia.example/api/v1',
      'query': 'https://api.sacdia.example/api/v1?source=release',
      'fragment': 'https://api.sacdia.example/api/v1#fragment',
      'escaped path': 'https://api.sacdia.example/%61pi/v1',
      'dot segment': 'https://api.sacdia.example/api/./v1',
      'parent segment': 'https://api.sacdia.example/api/x/../v1',
      'double slash': 'https://api.sacdia.example/api//v1',
      'trailing slash': 'https://api.sacdia.example/api/v1/',
      'explicit default port': 'https://api.sacdia.example:443/api/v1',
      'custom port': 'https://api.sacdia.example:8443/api/v1',
      'uppercase host': 'https://API.sacdia.example/api/v1',
      'leading whitespace': ' https://api.sacdia.example/api/v1',
      'malformed URL': 'not a URL',
    };

    for (final entry in rejectedValues.entries) {
      test('rejects ${entry.key}', () {
        expect(
          () => AppConstants.resolveBaseUrl(
            override: entry.value,
            isProduct: true,
          ),
          _throwsCode(AppConstants.releaseApiBaseUrlNotHttpsCode),
        );
      });
    }
  });

  test('apiBaseUrl is wired to the product resolver contract', () {
    final source = File(
      'lib/core/constants/app_constants.dart',
    ).readAsStringSync();

    expect(
      source,
      matches(
        RegExp(
          r"static const bool _isProduct\s*=\s*bool\.fromEnvironment\('dart\.vm\.product'\);",
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'static final String apiBaseUrl\s*=\s*resolveBaseUrl\(\s*override:\s*const String\.fromEnvironment\(apiBaseUrlDefineKey\),\s*isProduct:\s*_isProduct,\s*\);',
        ),
      ),
    );
    expect(source, isNot(contains('ALLOW_LOCAL_API_BASE_URL')));
  });
}

Matcher _throwsCode(String code) => throwsA(
      isA<StateError>().having((error) => error.message, 'message', code),
    );
