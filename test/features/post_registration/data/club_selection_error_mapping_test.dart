import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';

import '../../../support/http_adapters.dart';

const _baseUrl = 'http://localhost:3000/api/v1';

ClubSelectionRemoteDataSourceImpl _build(HttpClientAdapter adapter) {
  // Cadena real: el ErrorInterceptor es quien rechaza con AuthException/etc.
  final dio = Dio()
    ..httpClientAdapter = adapter
    ..interceptors.add(ErrorInterceptor());
  return ClubSelectionRemoteDataSourceImpl(dio: dio, baseUrl: _baseUrl);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getClubsByLocalField error mapping', () {
    test(
        'a 403 ACTING_FOR_SCOPE_DENIED keeps its code and is not a network '
        'error', () async {
      final ds = _build(JsonAdapter(403, {
        'status': 'error',
        'statusCode': 403,
        'code': 'ACTING_FOR_SCOPE_DENIED',
        'message': 'Forbidden',
        'details': {'secret': 'do-not-read'},
      }));

      await expectLater(
        ds.getClubsByLocalField(1),
        throwsA(
          isA<AppException>()
              .having(
                  (e) => e.errorCode, 'errorCode', 'ACTING_FOR_SCOPE_DENIED')
              .having((e) => e.code, 'http status', 403)
              .having((e) => e, 'not a connection error',
                  isNot(isA<ConnectionException>()))
              .having(
                  (e) => e.message, 'message', isNot(contains('Sin conexi'))),
        ),
      );
    });

    test('a 500 keeps its status instead of becoming a network error',
        () async {
      final ds = _build(JsonAdapter(500, {
        'status': 'error',
        'code': 'INTERNAL',
        'message': 'boom',
      }));

      await expectLater(
        ds.getClubsByLocalField(1),
        throwsA(
          isA<AppException>()
              .having((e) => e.errorCode, 'errorCode', 'INTERNAL')
              .having((e) => e.code, 'http status', 500),
        ),
      );
    });

    test('a real connection failure is still a ConnectionException', () async {
      final ds = _build(ErrorAdapter((options) => DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          )));

      await expectLater(
        ds.getClubsByLocalField(1),
        throwsA(isA<ConnectionException>()),
      );
    });

    test('a cancellation is rethrown untouched', () async {
      final ds = _build(ErrorAdapter((options) => DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
          )));

      await expectLater(
        ds.getClubsByLocalField(1),
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.cancel)),
      );
    });
  });
}
