import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/models/paginated_result.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _fullMeta({
  int page = 1,
  int limit = 50,
  int total = 3,
  int totalPages = 1,
  bool hasNextPage = false,
  bool hasPreviousPage = false,
}) =>
    {
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
      'hasNextPage': hasNextPage,
      'hasPreviousPage': hasPreviousPage,
    };

Map<String, dynamic> _snakeMeta() => {
      'page': 2,
      'limit': 10,
      'total': 25,
      'total_pages': 3,
      'has_next_page': true,
      'has_previous_page': true,
    };

Map<String, dynamic> _fullJson({List<Map<String, dynamic>>? data}) => {
      'data': data ??
          [
            {'id': 1, 'name': 'Alice'},
            {'id': 2, 'name': 'Bob'},
          ],
      'meta': _fullMeta(total: data?.length ?? 2),
    };

// ── PaginationMeta.fromJson ───────────────────────────────────────────────────

void main() {
  group('PaginationMeta.fromJson — camelCase keys', () {
    test('parses all fields correctly', () {
      final meta = PaginationMeta.fromJson(_fullMeta(
        page: 2,
        limit: 20,
        total: 100,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true,
      ));
      expect(meta.page, 2);
      expect(meta.limit, 20);
      expect(meta.total, 100);
      expect(meta.totalPages, 5);
      expect(meta.hasNextPage, isTrue);
      expect(meta.hasPreviousPage, isTrue);
    });

    test('hasNextPage defaults to derived value when absent', () {
      // page 1, totalPages 3 → hasNextPage should be true
      final json = {
        'page': 1,
        'limit': 10,
        'total': 30,
        'totalPages': 3,
      };
      final meta = PaginationMeta.fromJson(json);
      expect(meta.hasNextPage, isTrue);
      expect(meta.hasPreviousPage, isFalse);
    });

    test('last page: hasNextPage is false and hasPreviousPage is true', () {
      final json = {
        'page': 3,
        'limit': 10,
        'total': 30,
        'totalPages': 3,
      };
      final meta = PaginationMeta.fromJson(json);
      expect(meta.hasNextPage, isFalse);
      expect(meta.hasPreviousPage, isTrue);
    });
  });

  group('PaginationMeta.fromJson — snake_case keys', () {
    test('parses total_pages and has_next/previous_page variants', () {
      final meta = PaginationMeta.fromJson(_snakeMeta());
      expect(meta.page, 2);
      expect(meta.limit, 10);
      expect(meta.total, 25);
      expect(meta.totalPages, 3);
      expect(meta.hasNextPage, isTrue);
      expect(meta.hasPreviousPage, isTrue);
    });
  });

  group('PaginationMeta.fromJson — defaults', () {
    test('empty map returns safe defaults', () {
      final meta = PaginationMeta.fromJson({});
      expect(meta.page, 1);
      expect(meta.limit, 50);
      expect(meta.total, 0);
      expect(meta.totalPages, 1);
      expect(meta.hasNextPage, isFalse);
      expect(meta.hasPreviousPage, isFalse);
    });

    test('string-encoded integers are parsed', () {
      final meta = PaginationMeta.fromJson({
        'page': '2',
        'limit': '25',
        'total': '50',
        'totalPages': '2',
        'hasNextPage': false,
        'hasPreviousPage': true,
      });
      expect(meta.page, 2);
      expect(meta.limit, 25);
      expect(meta.total, 50);
      expect(meta.totalPages, 2);
    });
  });

  // ── PaginatedResult.fromJson ─────────────────────────────────────────────────

  String _parseName(Map<String, dynamic> json) => json['name'] as String;

  group('PaginatedResult.fromJson', () {
    test('valid JSON parses data list and meta correctly', () {
      final result = PaginatedResult.fromJson(
        _fullJson(),
        _parseName,
      );
      expect(result.data, ['Alice', 'Bob']);
      expect(result.meta.total, 2);
      expect(result.meta.page, 1);
    });

    test('empty data list returns empty list with meta preserved', () {
      final result = PaginatedResult.fromJson(
        {
          'data': <dynamic>[],
          'meta': _fullMeta(total: 0, totalPages: 1),
        },
        _parseName,
      );
      expect(result.data, isEmpty);
      expect(result.meta.total, 0);
      expect(result.meta.totalPages, 1);
    });

    test('missing meta key falls back to empty meta (all defaults)', () {
      // PaginatedResult.fromJson uses `?? {}` for meta — defaults apply.
      final result = PaginatedResult.fromJson(
        {'data': <dynamic>[]},
        _parseName,
      );
      expect(result.data, isEmpty);
      expect(result.meta.page, 1);
      expect(result.meta.total, 0);
    });

    test('missing data key falls back to empty list', () {
      final result = PaginatedResult.fromJson(
        {'meta': _fullMeta(total: 0)},
        _parseName,
      );
      expect(result.data, isEmpty);
    });

    test('parseItem is called once per element', () {
      var callCount = 0;
      PaginatedResult.fromJson(
        _fullJson(data: [
          {'id': 1, 'name': 'X'},
          {'id': 2, 'name': 'Y'},
          {'id': 3, 'name': 'Z'},
        ]),
        (json) {
          callCount++;
          return json['name'] as String;
        },
      );
      expect(callCount, 3);
    });
  });
}
