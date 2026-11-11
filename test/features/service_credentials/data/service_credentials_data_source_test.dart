import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/features/service_credentials/data/datasources/service_credentials_remote_data_source.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential_review.dart';

/// Answers in memory and records every request (shared log keeps the order
/// across the API client and the plain upload client).
class _FakeApi extends Interceptor {
  _FakeApi(this.log, this.respond);

  final List<RequestOptions> log;
  final ({int status, Object? body}) Function(RequestOptions options) respond;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log.add(options);
    final r = respond(options);
    final response = Response<Object?>(
      requestOptions: options,
      statusCode: r.status,
      data: r.body,
    );
    if (r.status >= 400) {
      handler.reject(DioException(
        requestOptions: options,
        response: response,
        type: DioExceptionType.badResponse,
      ));
    } else {
      handler.resolve(response);
    }
  }
}

const _credentialJson = {
  'credential_id': 'c1',
  'type': 'COUNSELOR_TRAINING',
  'status': 'PENDING_REVIEW',
  'upload_status': 'PENDING_UPLOAD',
};

void main() {
  late List<RequestOptions> log;
  late Directory tmp;
  late File pdf;

  setUp(() {
    log = [];
    tmp = Directory.systemTemp.createTempSync('sc_ds_test');
    pdf = File('${tmp.path}/constancia.pdf')..writeAsBytesSync([1, 2, 3, 4, 5]);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  ServiceCredentialsRemoteDataSourceImpl build({
    required ({int status, Object? body}) Function(RequestOptions o) api,
    ({int status, Object? body}) Function(RequestOptions o)? upload,
  }) =>
      ServiceCredentialsRemoteDataSourceImpl(
        dio: Dio()..interceptors.add(_FakeApi(log, api)),
        uploadDio: Dio()
          ..interceptors.add(_FakeApi(
            log,
            upload ?? (_) => (status: 200, body: null),
          )),
        baseUrl: 'http://api',
      );

  ConsentEvidenceLocalFile file() => ConsentEvidenceLocalFile(
        path: pdf.path,
        name: 'constancia.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 5,
      );

  final draft = ServiceCredentialDraft(
    completedAt: DateTime(2026, 3, 4),
  );

  const ticketBody = {
    'status': 'success',
    'data': {
      'credential': _credentialJson,
      'upload': {
        'url': 'https://r2.example/put?sig=1',
        'method': 'PUT',
        'headers': {'Content-Type': 'application/pdf', 'x-amz-meta': 'a'},
        'expires_in': 300,
      },
    },
  };

  ({int status, Object? body}) happy(RequestOptions o) {
    if (o.method == 'POST' && o.path.endsWith('/service-credentials')) {
      return (status: 201, body: ticketBody);
    }
    if (o.path.endsWith('/confirm')) {
      return (
        status: 200,
        body: {
          'status': 'success',
          'data': {..._credentialJson, 'upload_status': 'CONFIRMED'},
        }
      );
    }
    return (
      status: 200,
      body: {
        'status': 'success',
        'data': {'items': []}
      }
    );
  }

  test('getMine hits /users/me/service-credentials and skips X-Acting-For',
      () async {
    final ds = build(
      api: (_) => (
        status: 200,
        body: {
          'status': 'success',
          'data': {
            'items': [_credentialJson],
          },
        }
      ),
    );
    final list = await ds.getMine();
    expect(list.single.id, 'c1');
    expect(log.single.method, 'GET');
    expect(
        log.single.uri.toString(), 'http://api/users/me/service-credentials');
    expect(log.single.extra[AuthInterceptor.skipActingForKey], isTrue);
  });

  test('submit runs register -> PUT to the signed URL -> confirm in order',
      () async {
    final phases = <ServiceCredentialSubmitPhase>[];
    final ds = build(api: happy);
    final result = await ds.submit(
      draft: draft,
      file: file(),
      onPhase: phases.add,
    );

    expect(result.uploadStatus, ServiceCredentialUploadStatus.confirmed);
    expect(phases, [
      ServiceCredentialSubmitPhase.registering,
      ServiceCredentialSubmitPhase.uploading,
      ServiceCredentialSubmitPhase.confirming,
    ]);
    expect(log.map((r) => '${r.method} ${r.uri}'), [
      'POST http://api/users/me/service-credentials',
      'PUT https://r2.example/put?sig=1',
      'POST http://api/users/me/service-credentials/c1/confirm',
    ]);

    // Registration body: exactly the contract.
    expect(log[0].data, {
      'type': 'COUNSELOR_TRAINING',
      'completed_at': '2026-03-04',
      'file_name': 'constancia.pdf',
      'mime_type': 'application/pdf',
      'size_bytes': 5,
    });
    expect(log[0].extra[AuthInterceptor.skipActingForKey], isTrue);
    expect(log[2].extra[AuthInterceptor.skipActingForKey], isTrue);

    // The PUT carries the presigned headers and never an Authorization.
    final put = log[1];
    expect(put.headers['Content-Type'], 'application/pdf');
    expect(put.headers['x-amz-meta'], 'a');
    expect(put.headers['Content-Length'], '5');
    expect(put.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')));
    expect(put.extra.containsKey(AuthInterceptor.skipActingForKey), isFalse);
  });

  test('the PUT never forwards an Authorization header from the ticket',
      () async {
    final ds = build(api: (o) {
      final base = happy(o);
      if (o.method == 'POST' && o.path.endsWith('/service-credentials')) {
        return (
          status: 201,
          body: {
            'data': {
              'credential': _credentialJson,
              'upload': {
                'url': 'https://r2.example/put',
                'method': 'PUT',
                'headers': {'Authorization': 'Bearer leak'},
              },
            },
          }
        );
      }
      return base;
    });
    await ds.submit(draft: draft, file: file());
    expect(
      log[1].headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
  });

  test('the registration body has no variant and no hours', () async {
    final ds = build(api: happy);
    await ds.submit(draft: draft, file: file());
    final body = log[0].data as Map;
    expect(body['type'], 'COUNSELOR_TRAINING');
    expect(body.containsKey('variant'), isFalse);
    expect(body.containsKey('hours'), isFalse);
  });

  test('a failed PUT withdraws the credential and surfaces the failure',
      () async {
    final ds = build(
      api: (o) => o.method == 'DELETE'
          ? (status: 200, body: {'status': 'success'})
          : happy(o),
      upload: (_) => (status: 403, body: null),
    );
    await expectLater(
      ds.submit(draft: draft, file: file()),
      throwsA(isA<ServerException>().having(
        (e) => e.errorCode,
        'errorCode',
        'SERVICE_CREDENTIAL_UPLOAD_MISSING',
      )),
    );
    expect(log.map((r) => r.method), ['POST', 'PUT', 'DELETE']);
    expect(log[2].uri.toString(), 'http://api/users/me/service-credentials/c1');
    // Never confirmed.
    expect(log.any((r) => r.path.endsWith('/confirm')), isFalse);
  });

  test('a failed confirm keeps the business code and withdraws the draft',
      () async {
    final ds = build(api: (o) {
      if (o.path.endsWith('/confirm')) {
        return (
          status: 422,
          body: {'code': 'SERVICE_CREDENTIAL_UPLOAD_MISSING', 'message': 'm'},
        );
      }
      if (o.method == 'DELETE') return (status: 200, body: null);
      return happy(o);
    });
    await expectLater(
      ds.submit(draft: draft, file: file()),
      throwsA(isA<ServerException>().having(
        (e) => e.errorCode,
        'errorCode',
        'SERVICE_CREDENTIAL_UPLOAD_MISSING',
      )),
    );
    expect(log.last.method, 'DELETE');
  });

  test('a registration error is surfaced by code without touching R2',
      () async {
    final ds = build(
      api: (_) => (
        status: 409,
        body: {'code': 'SERVICE_CREDENTIAL_PENDING_EXISTS', 'message': 'm'},
      ),
    );
    await expectLater(
      ds.submit(draft: draft, file: file()),
      throwsA(isA<ServerException>().having(
        (e) => e.errorCode,
        'errorCode',
        'SERVICE_CREDENTIAL_PENDING_EXISTS',
      )),
    );
    expect(log, hasLength(1));
  });

  test('withdraw sends DELETE and skips X-Acting-For', () async {
    final ds = build(api: (_) => (status: 204, body: null));
    await ds.withdraw('c1');
    expect(log.single.method, 'DELETE');
    expect(log.single.uri.toString(),
        'http://api/users/me/service-credentials/c1');
    expect(log.single.extra[AuthInterceptor.skipActingForKey], isTrue);
  });

  test('getReviewQueue sends status, search and paging', () async {
    final ds = build(
      api: (_) => (
        status: 200,
        body: {
          'data': [],
          'meta': {
            'page': 2,
            'limit': 20,
            'total': 0,
            'counts': {'pending': 1},
          },
        }
      ),
    );
    final page = await ds.getReviewQueue(
      status: ReviewStatusFilter.rejected,
      search: ' laura ',
      page: 2,
    );
    expect(page.counts.pending, 1);
    expect(log.single.uri.path, '/service-credentials/review');
    expect(log.single.queryParameters, {
      'status': 'REJECTED',
      'search': 'laura',
      'page': 2,
      'limit': 20,
    });
    // Review is NOT a self call: it goes through the normal acting policy.
    expect(log.single.extra.containsKey(AuthInterceptor.skipActingForKey),
        isFalse);
  });

  test('getReviewQueue omits an empty search', () async {
    final ds = build(api: (_) => (status: 200, body: {'data': []}));
    await ds.getReviewQueue(status: ReviewStatusFilter.pending, search: '  ');
    expect(log.single.queryParameters.containsKey('search'), isFalse);
  });

  test('getReviewDetail reads the signed file', () async {
    final ds = build(
      api: (_) => (
        status: 200,
        body: {
          'data': {
            'credential_id': 'c1',
            'user': {'user_id': 'u', 'name': 'Laura'},
            'file_url': 'https://f/x.pdf',
            'mime_type': 'application/pdf',
          },
        }
      ),
    );
    final detail = await ds.getReviewDetail('c1');
    expect(log.single.uri.path, '/service-credentials/review/c1');
    expect(detail.isPdf, isTrue);
  });

  test('approve sends the optional expiry, reject sends the reason', () async {
    final ds = build(api: (_) => (status: 201, body: {'status': 'success'}));
    await ds.approve('c1');
    await ds.approve('c1', expiresAt: DateTime(2027, 1, 9));
    await ds.reject('c1', reason: 'Documento ilegible');
    expect(log[0].uri.path, '/service-credentials/review/c1/approve');
    expect(log[0].data, <String, dynamic>{});
    expect(log[1].data, {'expires_at': '2027-01-09'});
    expect(log[2].uri.path, '/service-credentials/review/c1/reject');
    expect(log[2].data, {'reason': 'Documento ilegible'});
  });

  test('a 409 keeps SERVICE_CREDENTIAL_NOT_PENDING for the UI', () async {
    final ds = build(
      api: (_) => (
        status: 409,
        body: {'code': 'SERVICE_CREDENTIAL_NOT_PENDING', 'message': 'm'},
      ),
    );
    await expectLater(
      ds.approve('c1'),
      throwsA(isA<ServerException>().having(
        (e) => e.errorCode,
        'errorCode',
        'SERVICE_CREDENTIAL_NOT_PENDING',
      )),
    );
  });
}
