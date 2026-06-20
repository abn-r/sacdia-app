import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Inventory translations', () {
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      test('defines item count plural keys for $locale', () async {
        final raw = await rootBundle.loadString(
          'assets/translations/$locale.json',
        );
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final inventory = json['inventory'] as Map<String, dynamic>;
        final view = inventory['view'] as Map<String, dynamic>;
        final itemCount = view['item_count'] as Map<String, dynamic>;

        expect(itemCount['one'], isA<String>());
        expect(itemCount['other'], isA<String>());
        expect(itemCount['one'], contains('{count}'));
        expect(itemCount['other'], contains('{count}'));
      });
    }
  });
}
