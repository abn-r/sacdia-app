import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/features/certificate_import/data/repositories/certificate_import_repository_impl.dart';
import 'package:sacdia_app/features/certificate_import/data/datasources/certificate_import_remote_data_source.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_payloads.dart';

class _ConnectedNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.confirmError});

  final Map<String, dynamic>? confirmError;
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
      if (confirmError != null) return _json(confirmError!, status: 400);
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
  final errors = <String>[
    'CERTIFICATE_IMPORT_PDF_TOO_MANY_PAGES',
    'CERTIFICATE_IMPORT_PDF_INVALID',
    'CERTIFICATE_IMPORT_PDF_ENCRYPTED',
    'Inténtalo más tarde: el almacenamiento no está disponible.',
  ];
  for (final errorCode in errors) {
    for (final withCode in [true, false]) {
      for (final withInterceptor in [true, false]) {
        test(
            'preserves confirm error $errorCode (code: $withCode, interceptor: $withInterceptor)',
            () async {
          final temp = await File(
            '${Directory.systemTemp.path}/sacdia_pdf_${DateTime.now().microsecondsSinceEpoch}.pdf',
          ).writeAsBytes([37, 80, 68, 70]);
          addTearDown(() => temp.delete());
          final apiAdapter = _RecordingAdapter(confirmError: {
            'status': 'error',
            if (withCode)
              'code': errorCode.startsWith('CERTIFICATE_IMPORT_PDF_')
                  ? errorCode
                  : 'CERTIFICATE_IMPORT_STORAGE_UNAVAILABLE',
            'message':
                withCode && errorCode.startsWith('CERTIFICATE_IMPORT_PDF_')
                    ? 'Internal parser detail /private/input.pdf'
                    : errorCode,
          });
          final apiDio = Dio(BaseOptions(responseType: ResponseType.json))
            ..httpClientAdapter = apiAdapter;
          if (withInterceptor) apiDio.interceptors.add(ErrorInterceptor());
          final repository = CertificateImportRepositoryImpl(
            remoteDataSource: CertificateImportRemoteDataSourceImpl(
              dio: apiDio,
              baseUrl: 'http://localhost:3000/api/v1',
              uploadDio: Dio()..httpClientAdapter = _RecordingAdapter(),
            ),
            networkInfo: _ConnectedNetworkInfo(),
          );
          final result = await repository.uploadLocalProof(
            CertificateImportLocalProof(
              localPath: temp.path,
              fileName: 'cert.pdf',
              mimeType: 'application/pdf',
              fileSize: 4,
            ),
          );
          result.fold((failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, errorCode);
            expect(failure.code, 400);
          }, (_) => fail('PDF rejection must not produce a confirmed batch'));
          expect(apiAdapter.requests.map((r) => r.method),
              ['POST', 'POST', 'POST']);
        });
      }
    }
  }

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
      final createBody =
          apiAdapter.bodies[apiAdapter.requests.indexOf(createCall)];
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
