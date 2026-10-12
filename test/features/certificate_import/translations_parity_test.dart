import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _keys(Object? node, [String prefix = '']) {
  if (node is! Map) return {prefix};
  return {
    for (final entry in node.entries)
      ..._keys(entry.value,
          prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}'),
  };
}

void main() {
  test('certificate_import has the same keys in all four languages', () {
    Map<String, dynamic> section(String lang) {
      final json = jsonDecode(
        File('assets/translations/$lang.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      return json['certificate_import'] as Map<String, dynamic>;
    }

    final es = _keys(section('es'));
    for (final lang in ['en', 'fr', 'pt-BR']) {
      final other = _keys(section(lang));
      expect(other.difference(es), isEmpty, reason: 'extra keys in $lang');
      expect(es.difference(other), isEmpty, reason: 'missing keys in $lang');
    }
  });

  test('the Spanish copy says Especialidad, never Honor', () {
    final json = jsonDecode(
      File('assets/translations/es.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final values = <String>[];
    void walk(Object? node) {
      if (node is Map) {
        node.values.forEach(walk);
      } else if (node is String) {
        values.add(node);
      }
    }

    walk(json['certificate_import']);
    expect(values.where((v) => v.toLowerCase().contains('honor')), isEmpty);
  });
}
