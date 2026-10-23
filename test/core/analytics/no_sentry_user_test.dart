import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardas de privacidad para menores (FP3-30, privacidad §6.1).
///
/// Ningún menor de 13 a 17 ni teléfono vinculado puede ser identificado en
/// PostHog ni en Sentry. La app hoy no llama a ninguno de los dos para poner un
/// usuario: estos escaneos fallan si alguien lo introduce sin pasar por
/// `AnalyticsPolicy`.
List<File> _dartFilesUnderLib() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Líneas de código (sin comentarios `//`) que contienen [pattern].
List<String> _hits(RegExp pattern, {bool Function(File)? skip}) {
  final out = <String>[];
  for (final file in _dartFilesUnderLib()) {
    if (skip != null && skip(file)) continue;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final code = lines[i].split('//').first;
      if (pattern.hasMatch(code)) out.add('${file.path}:${i + 1}');
    }
  }
  return out;
}

void main() {
  test('the app never sets a Sentry user', () {
    expect(_hits(RegExp(r'Sentry\.configureScope')), isEmpty);
    expect(_hits(RegExp(r'\bsetUser\(')), isEmpty);
    expect(_hits(RegExp(r'\bSentryUser\b')), isEmpty);
  });

  test('Sentry keeps sendDefaultPii off', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('options.sendDefaultPii = false'));
  });

  test('PostHog identity calls live only in the analytics layer', () {
    bool inAnalytics(File f) =>
        f.path.replaceAll('\\', '/').startsWith('lib/core/analytics/');
    expect(
      _hits(
        RegExp(
            r'Posthog\(\)\s*\.\s*(identify|alias|group|setPersonProperties)'),
        skip: inAnalytics,
      ),
      isEmpty,
    );
  });

  test('identifyAnalyticsUser is called only by AnalyticsPolicy', () {
    final callers = _hits(
      RegExp(r'\bidentifyAnalyticsUser\('),
      skip: (f) {
        final path = f.path.replaceAll('\\', '/');
        // La declaración y la pasarela que la envuelve.
        return path == 'lib/core/analytics/posthog_analytics.dart' ||
            path == 'lib/core/analytics/analytics_policy.dart';
      },
    );
    expect(callers, isEmpty, reason: 'route identification through the policy');
  });

  test('the policy file is the only caller of the gateway identify', () {
    final callers = _hits(
      RegExp(r'\bgateway\.identify\('),
      skip: (f) =>
          f.path.replaceAll('\\', '/') ==
          'lib/core/analytics/analytics_policy.dart',
    );
    expect(callers, isEmpty);
  });
}
