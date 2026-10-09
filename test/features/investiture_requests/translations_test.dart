import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _keys(Object? node, [String prefix = '']) {
  if (node is Map<String, dynamic>) {
    return {
      for (final entry in node.entries)
        ..._keys(
            entry.value, prefix.isEmpty ? entry.key : '$prefix.${entry.key}'),
    };
  }
  return {prefix};
}

Map<String, dynamic> _block(String lang) {
  final json =
      jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
          as Map<String, dynamic>;
  return json['investiture_requests'] as Map<String, dynamic>;
}

void main() {
  test('investiture_requests has the same keys in every language', () {
    final es = _keys(_block('es'));
    for (final lang in ['en', 'fr', 'pt-BR']) {
      final keys = _keys(_block(lang));
      expect(es.difference(keys), isEmpty, reason: '$lang is missing keys');
      expect(keys.difference(es), isEmpty, reason: '$lang has extra keys');
    }
  });
}
