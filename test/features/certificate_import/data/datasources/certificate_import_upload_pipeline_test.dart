import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certificate_import/data/datasources/certificate_import_remote_data_source.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_payloads.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<String?> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bytes = await requestStream.expand((chunk) => chunk).toList();
      try {
        bodies.add(utf8.decode(bytes));
      } catch (_) {
        bodies.add(null);
      }
    } else {
      bodies.add(null);
    }

    final path = options.uri.path;
    final method = options.method.toUpperCase();

    if (method == 'POST' && path.endsWith('/certificate-bulk-imports')) {
      return _json({
        'status': 'success',
        'data': {
          'batch_id': 'batch-1',
          'status': 'DRAFT',
          'files': [],
          'items': [],
        },
      });
    }

    if (method == 'POST' && path.endsWith('/files/presign')) {
      return _json({
        'status': 'success',
        'data': {
          'file_id': 'file-1',
          'upload_url': 'https://r2.example.test/upload/cert.jpg',
          'expires_in': 900,
          'required_headers': {'Content-Type': 'image/jpeg'},
        },
      });
    }

    if (method == 'PUT' &&
        options.uri.toString() == 'https://r2.example.test/upload/cert.jpg') {
      return ResponseBody.fromString(
        '',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
        },
      );
    }

    if (method == 'POST' && path.endsWith('/files/file-1/confirm')) {
      return _json({
        'status': 'success',
        'data': {
          'file_id': 'file-1',
          'file_url': 'batches/batch-1/sealed/file-1.jpg',
          'file_name': 'cert.jpg',
          'file_type': 'image/jpeg',
          'upload_status': 'CONFIRMED',
        },
      });
    }

    if (method == 'GET' && path.endsWith('/certificate-bulk-imports/batch-1')) {
      return _json({
        'status': 'success',
        'data': {
          'batch_id': 'batch-1',
          'status': 'DRAFT',
          'files': [
            {
              'file_id': 'file-1',
              'file_url': 'batches/batch-1/sealed/file-1.jpg',
              'file_name': 'cert.jpg',
              'file_type': 'image/jpeg',
              'upload_status': 'CONFIRMED',
            },
          ],
          'items': [],
        },
      });
    }

    return _json({
      'status': 'error',
      'message': 'unexpected ${options.method} ${options.uri}',
    }, status: 500);
  }

  ResponseBody _json(Map<String, dynamic> body, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'uploadLocalProof never sends file.path as file_url and PUTs to R2 without Authorization',
    () async {
      final temp = File(
        '${Directory.systemTemp.path}/sacdia_cert_import_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await temp.writeAsBytes(List<int>.filled(64, 7));
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync();
      });

      final apiAdapter = _RecordingAdapter();
      final uploadAdapter = _RecordingAdapter();
      final apiDio = Dio(BaseOptions(responseType: ResponseType.json))
        ..httpClientAdapter = apiAdapter
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              options.headers['Authorization'] = 'Bearer test-token';
              handler.next(options);
            },
          ),
        );
      final uploadDio = Dio()..httpClientAdapter = uploadAdapter;

      final dataSource = CertificateImportRemoteDataSourceImpl(
        dio: apiDio,
        baseUrl: 'http://localhost:3000/api/v1',
        uploadDio: uploadDio,
      );

      final batch = await dataSource.uploadLocalProof(
        CertificateImportLocalProof(
          localPath: temp.path,
          fileName: 'cert.jpg',
          mimeType: 'image/jpeg',
          fileSize: await temp.length(),
        ),
      );

      expect(batch.id, 'batch-1');

      final createCall = apiAdapter.requests.firstWhere(
        (r) =>
            r.method.toUpperCase() == 'POST' &&
            r.uri.path.endsWith('/certificate-bulk-imports'),
      );
      final createBody = apiAdapter.bodies[
          apiAdapter.requests.indexOf(createCall)];
      expect(createBody, isNotNull);
      expect(createBody, isNot(contains(temp.path)));
      expect(createBody, isNot(contains('"file_url"')));

      final putCall = uploadAdapter.requests.singleWhere(
        (r) => r.method.toUpperCase() == 'PUT',
      );
      expect(putCall.uri.toString(), 'https://r2.example.test/upload/cert.jpg');
      expect(putCall.headers['Authorization'], isNull);
      expect(
        putCall.headers.keys
            .map((k) => k.toLowerCase())
            .contains('authorization'),
        isFalse,
      );
    },
  );
}
