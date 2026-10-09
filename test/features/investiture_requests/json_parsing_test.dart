import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/investiture_requests/data/models/json_parsing.dart';

void main() {
  group('extractInvestitureListFromResponse', () {
    test('reads a bare list', () {
      expect(extractInvestitureListFromResponse([1, 2], 'items'), [1, 2]);
    });

    test('reads data.<key> from the success envelope', () {
      expect(
        extractInvestitureListFromResponse({
          'status': 'success',
          'data': {
            'history': [1]
          },
        }, 'history'),
        [1],
      );
    });

    test('reads data as a list and data.items', () {
      expect(
          extractInvestitureListFromResponse({
            'data': [3]
          }, 'x'),
          [3]);
      expect(
        extractInvestitureListFromResponse({
          'data': {
            'items': [4]
          }
        }, 'x'),
        [4],
      );
    });

    test('returns an empty list for anything else', () {
      expect(extractInvestitureListFromResponse('nope', 'x'), isEmpty);
    });
  });
}
