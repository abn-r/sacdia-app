import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _forbidden = <RegExp>[
  RegExp(r'submit-for-validation'),
  RegExp(r'/investiture/pending'),
  RegExp(r'\$\{ApiEndpoints\.investiture\}'),
  RegExp(r"enrollments\}/\$\w+/(validate|investiture|investiture-history)'"),
  RegExp(r'features/investiture/(data|presentation)/'),
  RegExp(r'ValidationEntityType\.classProgress'),
];

bool _flags(String line) => _forbidden.any((pattern) => pattern.hasMatch(line));

void main() {
  group('each forbidden pattern flags an example', () {
    final samples = <String, String>{
      'submit-for-validation': r"'/enrollments/$id/submit-for-validation'",
      '/investiture/pending': r"'/investiture/pending'",
      'ApiEndpoints.investiture': r"'${ApiEndpoints.investiture}/enrollments'",
      'validate': r"'${ApiEndpoints.enrollments}/$id/validate'",
      'investiture': r"'${ApiEndpoints.enrollments}/$id/investiture'",
      'investiture-history':
          r"'${ApiEndpoints.enrollments}/$id/investiture-history'",
      'old feature data':
          r"import 'package:sacdia/features/investiture/data/x.dart';",
      'old feature presentation':
          r"import 'package:sacdia/features/investiture/presentation/x.dart';",
      'ValidationEntityType.classProgress':
          'ValidationEntityType.classProgress',
    };
    for (final entry in samples.entries) {
      test(entry.key, () => expect(_flags(entry.value), isTrue));
    }

    test('does not flag the new authorization flow', () {
      expect(_flags(r"'${ApiEndpoints.enrollments}/$id/progress'"), isFalse);
      expect(
        _flags("import 'package:sacdia/features/investiture_requests/x.dart';"),
        isFalse,
      );
    });
  });

  test('the app no longer reaches the retired investiture pipeline', () {
    final root = Directory.current.path;
    final offenders = <String>[];
    for (final entity in Directory('$root/lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (_forbidden.any((pattern) => pattern.hasMatch(line))) {
          offenders.add('${entity.path.substring(root.length + 1)}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
