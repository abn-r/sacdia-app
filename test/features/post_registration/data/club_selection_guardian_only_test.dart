import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';

import '../../../support/http_adapters.dart';

const _baseUrl = 'http://localhost:3000/api/v1';

({ClubSelectionRemoteDataSourceImpl ds, JsonAdapter adapter}) _build(
  int status,
  Object body,
) {
  final adapter = JsonAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (
    ds: ClubSelectionRemoteDataSourceImpl(dio: dio, baseUrl: _baseUrl),
    adapter: adapter,
  );
}

void main() {
  group('completeGuardianOnly', () {
    test('posts to step-3/guardian-only with an empty body by default',
        () async {
      final t = _build(200, {
        'status': 'success',
        'data': {'mode': 'guardian_only'},
      });

      await t.ds.completeGuardianOnly(userId: 'user-1');

      final request = t.adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(
        request.path,
        '$_baseUrl/users/user-1/post-registration/step-3/guardian-only',
      );
      expect(request.data, <String, dynamic>{});
    });

    test('sends the geography only when it was picked', () async {
      final t = _build(200, {'status': 'success'});

      await t.ds.completeGuardianOnly(
        userId: 'user-1',
        countryId: 1,
        unionId: 2,
        localFieldId: 3,
      );

      expect(t.adapter.lastRequest!.data, {
        'country_id': 1,
        'union_id': 2,
        'local_field_id': 3,
      });
    });

    test('keeps the business code of the 422 (minor) and never reads details',
        () async {
      final t = _build(422, {
        'status': 'error',
        'statusCode': 422,
        'code': 'POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT',
        'message': 'Only adults can register as guardian-only',
        'details': {'ignored': true},
      });

      await expectLater(
        t.ds.completeGuardianOnly(userId: 'user-1'),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', 422).having(
                (e) => e.errorCode,
                'errorCode',
                'POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT',
              ),
        ),
      );
    });

    test('maps a 403 to AuthException keeping the code', () async {
      final t = _build(403, {
        'code': 'ACTING_FOR_SCOPE_DENIED',
        'message': 'denied',
      });

      await expectLater(
        t.ds.completeGuardianOnly(userId: 'user-1'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ACTING_FOR_SCOPE_DENIED',
          ),
        ),
      );
    });

    test('a dropped connection becomes a ConnectionException', () async {
      final adapter = ErrorAdapter(
        (o) => DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = ClubSelectionRemoteDataSourceImpl(dio: dio, baseUrl: _baseUrl);

      await expectLater(
        ds.completeGuardianOnly(userId: 'user-1'),
        throwsA(isA<ConnectionException>()),
      );
    });
  });
}
