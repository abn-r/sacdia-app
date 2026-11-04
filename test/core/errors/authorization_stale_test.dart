import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/authorization_stale.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';

void main() {
  final options = RequestOptions(path: '/activities', method: 'POST');

  DioException rejection({Object? data, int status = 403}) => DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: data,
        ),
      );

  group('isAuthorizationStale', () {
    test('recognises the code on every error shape', () {
      final dio = rejection(
        data: {'code': 'AUTHORIZATION_STALE', 'message': 'Sin verificar'},
      );
      expect(isAuthorizationStale(dio), isTrue);
      expect(isAuthorizationStale(dio.response), isTrue);
      expect(isAuthorizationStale('authorization_stale'), isTrue);
      expect(
        isAuthorizationStale(
          AuthException(
              message: 'x', code: 403, errorCode: 'AUTHORIZATION_STALE'),
        ),
        isTrue,
      );
      expect(
        isAuthorizationStale(
          const AuthFailure(
              message: 'x', code: 403, errorCode: 'AUTHORIZATION_STALE'),
        ),
        isTrue,
      );
    });

    test('any other 403 is not stale', () {
      expect(
        isAuthorizationStale(
          rejection(data: {'code': 'GUARD_PERMISSION_DENIED', 'message': 'x'}),
        ),
        isFalse,
      );
      expect(isAuthorizationStale(rejection(data: 'forbidden')), isFalse);
      expect(isAuthorizationStale(rejection(data: null)), isFalse);
      expect(isAuthorizationStale(null), isFalse);
      expect(isAuthorizationStale(AuthException(message: 'x', code: 403)),
          isFalse);
    });
  });

  group('authorizationStaleException', () {
    test('keeps the interceptor message, the status and the code', () {
      final e = authorizationStaleException(
        rejection(
          data: {'code': 'AUTHORIZATION_STALE', 'message': 'Sin verificar'},
        ),
      );
      expect(e, isA<AuthException>());
      expect(e.message, 'Sin verificar');
      expect(e.code, 403);
      expect(e.errorCode, kAuthorizationStaleCode);
    });
  });
}
