import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';

/// Answers `GET /clubs` with [pages] (1-based) and records each query.
class _PagedAdapter implements HttpClientAdapter {
  _PagedAdapter(this.pages);

  final List<List<Map<String, dynamic>>> pages;
  final queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(Map.of(options.queryParameters));
    final page = options.queryParameters['page'] as int;
    final body = {
      'data': pages[page - 1],
      'meta': {
        'page': page,
        'hasNextPage': page < pages.length,
      },
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _club(int id) =>
    {'club_id': id, 'name': 'Club $id', 'local_field_id': 4};

void main() {
  test('reads every page of clubs of a local field', () async {
    final adapter = _PagedAdapter([
      [for (var i = 1; i <= 100; i++) _club(i)],
      [_club(101), _club(102)],
    ]);
    final ds = ClubSelectionRemoteDataSourceImpl(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'http://localhost:3000/api/v1',
    );

    final clubs = await ds.getClubsByLocalField(4);

    expect(clubs, hasLength(102));
    expect(clubs.last.id, 102);
    expect(adapter.queries.map((q) => q['page']), [1, 2]);
    expect(adapter.queries.first['limit'], 100);
    expect(adapter.queries.first['localFieldId'], 4);
  });

  test('one page without a next page makes one request', () async {
    final adapter = _PagedAdapter([
      [_club(1), _club(2)],
    ]);
    final ds = ClubSelectionRemoteDataSourceImpl(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'http://localhost:3000/api/v1',
    );

    expect(await ds.getClubsByLocalField(4), hasLength(2));
    expect(adapter.queries, hasLength(1));
  });
}
