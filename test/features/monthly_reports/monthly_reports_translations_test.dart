import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _keyPattern = RegExp(r"'(monthly_reports\.[a-z0-9_.]+)'");

void main() {
  group('Monthly reports translations', () {
    late Set<String> keysFromDart;

    setUpAll(() {
      keysFromDart = {};
      final dir = Directory('lib/features/monthly_reports');
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        keysFromDart.addAll(
          _keyPattern
              .allMatches(entity.readAsStringSync())
              .map((match) => match.group(1)!),
        );
      }
    });

    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      test('should define every monthly_reports key used in Dart for $locale',
          () {
        expect(keysFromDart, isNotEmpty);

        final json = jsonDecode(
          File('assets/translations/$locale.json').readAsStringSync(),
        ) as Map<String, dynamic>;

        final missing = [
          for (final key in keysFromDart)
            if (_lookup(json, key) == null) key,
        ]..sort();

        expect(
          missing,
          isEmpty,
          reason: 'Missing in $locale.json: $missing',
        );
      });
    }
  });
}

Object? _lookup(Map<String, dynamic> json, String dotted) {
  Object? current = json;
  for (final part in dotted.split('.')) {
    if (current is! Map<String, dynamic> || !current.containsKey(part)) {
      return null;
    }
    current = current[part];
  }
  if (current is String && current.isEmpty) {
    return null;
  }
  return current;
}
