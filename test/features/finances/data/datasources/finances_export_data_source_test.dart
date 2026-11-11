import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/finances/data/datasources/finances_remote_data_source.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_export.dart';

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.status, this.bytes, {this.headers = const {}});

  final int status;
  final List<int> bytes;
  final Map<String, List<String>> headers;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromBytes(bytes, status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

FinancesRemoteDataSourceImpl _source(_BytesAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return FinancesRemoteDataSourceImpl(dio: dio, baseUrl: 'http://api/v1');
}

void main() {
  test('downloads the month as bytes with the server file name', () async {
    final adapter = _BytesAdapter(
      200,
      [1, 2, 3],
      headers: {
        'content-disposition': [
          'attachment; filename="finanzas-central-2026-09.xlsx"',
        ],
      },
    );

    final file = await _source(adapter).exportFinances(
      clubId: 7,
      year: 2026,
      month: 9,
      format: FinanceExportFormat.xlsx,
    );

    expect(file.bytes, [1, 2, 3]);
    expect(file.fileName, 'finanzas-central-2026-09.xlsx');
    expect(adapter.last?.path, 'http://api/v1/clubs/7/finances/export');
    expect(adapter.last?.queryParameters, {
      'year': 2026,
      'month': 9,
      'format': 'xlsx',
    });
    expect(adapter.last?.responseType, ResponseType.bytes);
  });

  test('uses the fallback name when the server sends no header', () async {
    final file = await _source(_BytesAdapter(200, [9])).exportFinances(
      clubId: 7,
      year: 2026,
      month: 9,
      format: FinanceExportFormat.pdf,
    );

    expect(file.fileName, 'finanzas-2026-09.pdf');
  });

  test('keeps the HTTP status on failure so 403 can be told apart', () async {
    await expectLater(
      _source(_BytesAdapter(403, [])).exportFinances(
        clubId: 7,
        year: 2026,
        month: 9,
        format: FinanceExportFormat.pdf,
      ),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 403)),
    );
  });
}
