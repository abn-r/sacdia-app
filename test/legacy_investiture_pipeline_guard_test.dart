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

void main() {
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
