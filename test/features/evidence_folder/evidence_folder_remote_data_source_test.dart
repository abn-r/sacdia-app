import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/evidence_folder/data/datasources/evidence_folder_remote_data_source.dart';

class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this._responses);

  final List<ResponseBody> _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_responses.isEmpty) {
      return ResponseBody.fromString('No response queued', 500);
    }
    return _responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

({Dio dio, _QueuedAdapter adapter}) _dioWithResponses(
  List<ResponseBody> responses,
) {
  final adapter = _QueuedAdapter(responses);
  final dio = Dio(BaseOptions(responseType: ResponseType.json));
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

void main() {
  const baseUrl = 'http://localhost:3000/api/v1';

  group('EvidenceFolderRemoteDataSourceImpl.createEvidenceFolder', () {
    test('creates the folder by club section and reloads canonical detail',
        () async {
      final (:dio, :adapter) = _dioWithResponses([
        _jsonResponse({
          'status': 'success',
          'data': {'annual_folder_id': 'raw-create-response'},
        }, statusCode: 201),
        _jsonResponse({
          'status': 'success',
          'data': {
            'annual_folder_id': 'folder-1',
            'status': 'open',
            'total_earned_points': 0,
            'total_max_points': 4000,
            'progress_percentage': 0,
            'template': {'name': 'Carpeta Conquistadores ACV 2026'},
            'sections': [],
          },
        }),
      ]);
      final ds = EvidenceFolderRemoteDataSourceImpl(
        dio: dio,
        baseUrl: baseUrl,
      );

      final folder = await ds.createEvidenceFolder('2');

      expect(folder.folderId, 'folder-1');
      expect(folder.name, 'Carpeta Conquistadores ACV 2026');
      expect(adapter.requests.map((request) => request.method).toList(), [
        'POST',
        'GET',
      ]);
      expect(
        adapter.requests.map((request) => request.path).toList(),
        [
          '$baseUrl/club-sections/2/annual-folder',
          '$baseUrl/club-sections/2/annual-folder',
        ],
      );
    });
  });
}
