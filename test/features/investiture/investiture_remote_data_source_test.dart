import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/investiture/data/datasources/investiture_remote_data_source.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._body);

  final ResponseBody _body;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return _body;
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _FakeAdapter adapter}) _dioWith(
  Map<String, dynamic> response, {
  int statusCode = 200,
}) {
  final adapter = _FakeAdapter(
    ResponseBody.fromString(
      jsonEncode(response),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    ),
  );
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

Map<String, dynamic> _success([Map<String, dynamic> data = const {}]) => {
      'status': 'success',
      'data': data,
    };

void main() {
  const baseUrl = 'https://api.test/api/v1';

  InvestitureRemoteDataSourceImpl sourceFor(
    ({Dio dio, _FakeAdapter adapter}) setup,
  ) =>
      InvestitureRemoteDataSourceImpl(dio: setup.dio, baseUrl: baseUrl);

  group('InvestitureRemoteDataSourceImpl', () {
    test('submits to the canonical route with the required body', () async {
      final setup = _dioWith(_success());
      final source = sourceFor(setup);

      await source.submitForValidation(
        enrollmentId: 42,
        clubId: 7,
        comments: 'Ready for review',
      );

      expect(
        setup.adapter.lastOptions?.path,
        '$baseUrl/investiture/enrollments/42/submit',
      );
      expect(setup.adapter.lastOptions?.method, 'POST');
      expect(setup.adapter.lastOptions?.data, {
        'club_id': 7,
        'comments': 'Ready for review',
      });
    });

    test('approves through the coordinator route without a legacy action',
        () async {
      final setup = _dioWith(_success());
      final source = sourceFor(setup);

      await source.validateEnrollment(
        enrollmentId: 42,
        action: 'APPROVED',
        comments: 'Verified',
      );

      expect(
        setup.adapter.lastOptions?.path,
        '$baseUrl/investiture/enrollments/42/coordinator-approve',
      );
      expect(setup.adapter.lastOptions?.data, {'comments': 'Verified'});
    });

    test('rejects through the canonical route with its required reason',
        () async {
      final setup = _dioWith(_success());
      final source = sourceFor(setup);

      await source.validateEnrollment(
        enrollmentId: 42,
        action: 'REJECTED',
        comments: 'Missing evidence',
      );

      expect(
        setup.adapter.lastOptions?.path,
        '$baseUrl/investiture/enrollments/42/reject',
      );
      expect(setup.adapter.lastOptions?.data, {'reason': 'Missing evidence'});
    });

    test('requests coordinator pending rows and parses the canonical envelope',
        () async {
      final setup = _dioWith(_success({
        'data': [
          {
            'enrollment_id': 42,
            'investiture_status': 'CLUB_APPROVED',
            'submitted_at': '2026-08-01T12:00:00.000Z',
            'submitted_comment': 'Completed requirements',
            'user': {
              'user_id': 'member-1',
              'first_name': 'Ana',
              'last_name': 'Pérez Gómez',
              'photo': 'https://cdn.test/ana.jpg',
            },
            'class': {'class_id': 9, 'name': 'Guía'},
            'club': {'club_id': 3, 'name': 'Central'},
          },
        ],
        'total': 1,
        'page': 1,
        'limit': 20,
      }));
      final source = sourceFor(setup);

      final result = await source.getPendingInvestitures();

      expect(setup.adapter.lastOptions?.path, '$baseUrl/investiture/pending');
      expect(setup.adapter.lastOptions?.queryParameters, {
        'status': 'CLUB_APPROVED',
        'page': 1,
        'limit': 20,
      });
      expect(result, hasLength(1));
      expect(result.single.userName, 'Ana');
      expect(result.single.userLastName, 'Pérez Gómez');
      expect(result.single.userPhotoUrl, 'https://cdn.test/ana.jpg');
      expect(result.single.comments, 'Completed requirements');
    });

    test('uses the canonical history route and envelope', () async {
      final setup = _dioWith(_success({
        'enrollment_id': 42,
        'history': [
          {
            'history_id': 1,
            'action': 'CLUB_APPROVED',
            'performed_by': {'name': 'Ana', 'paternal_last_name': 'Pérez'},
            'comments': 'Approved',
            'created_at': '2026-08-01T12:00:00.000Z',
          },
        ],
      }));
      final source = sourceFor(setup);

      final result = await source.getInvestitureHistory(enrollmentId: 42);

      expect(
        setup.adapter.lastOptions?.path,
        '$baseUrl/investiture/enrollments/42/history',
      );
      expect(result, hasLength(1));
      expect(result.single.performerName, 'Ana');
    });

    for (final statusCode in [403, 404, 409]) {
      test('maps HTTP $statusCode to a domain exception', () async {
        final setup =
            _dioWith({'message': 'Backend error'}, statusCode: statusCode);
        final source = sourceFor(setup);

        final expectation =
            statusCode == 403 ? isA<AuthException>() : isA<ServerException>();

        await expectLater(
          () => source.submitForValidation(enrollmentId: 42, clubId: 7),
          throwsA(expectation),
        );
      });
    }
  });
}
