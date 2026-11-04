import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';

import '../../features/family/family_test_harness.dart';

DioException _dio(int status, {String? code}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: code == null ? {'message': 'x'} : {'code': code, 'message': 'x'},
      ),
    );

void main() {
  setUpAll(initLocalization);

  group('isForbiddenFailure', () {
    test('HTTP 403 is forbidden for failures, exceptions and Dio errors', () {
      expect(isForbiddenFailure(const ServerFailure(message: 'x', code: 403)),
          isTrue);
      expect(isForbiddenFailure(const AuthFailure(message: 'x', code: 403)),
          isTrue);
      expect(
          isForbiddenFailure(AuthException(message: 'x', code: 403)), isTrue);
      expect(isForbiddenFailure(_dio(403)), isTrue);
    });

    test('business codes mean forbidden whatever the status', () {
      for (final code in [
        'GUARD_PERMISSION_DENIED',
        'GUARD_CLUB_SCOPE_REQUIRED',
        'INVESTITURE_REQUEST_FORBIDDEN',
        'guardianship_revoke_forbidden',
      ]) {
        expect(
          isForbiddenFailure(
            ServerFailure(message: 'x', code: 400, errorCode: code),
          ),
          isTrue,
          reason: code,
        );
        expect(isForbiddenFailure(_dio(409, code: code)), isTrue, reason: code);
      }
    });

    test('acting-for, principal scope and stale rejections are excluded', () {
      for (final code in [
        'ACTING_FOR_FORBIDDEN',
        'ACTING_FOR_SCOPE_DENIED',
        'PRINCIPAL_SCOPE_DENIED',
        'AUTHORIZATION_STALE',
      ]) {
        expect(
          isForbiddenFailure(
            AuthFailure(message: 'x', code: 403, errorCode: code),
          ),
          isFalse,
          reason: code,
        );
        expect(isForbiddenFailure(_dio(403, code: code)), isFalse,
            reason: code);
      }
    });

    test('other errors are not forbidden', () {
      expect(isForbiddenFailure(const ServerFailure(message: 'x', code: 500)),
          isFalse);
      expect(isForbiddenFailure(const NetworkFailure(message: 'offline')),
          isFalse);
      expect(isForbiddenFailure(_dio(404)), isFalse);
      expect(isForbiddenFailure(StateError('boom')), isFalse);
      expect(isForbiddenFailure('permiso 403'), isFalse);
    });

    test('CoordinatorLoadException follows the same rule', () {
      expect(
        isForbiddenFailure(CoordinatorLoadException.fromFailure(
          const ServerFailure(message: 'x', code: 403),
        )),
        isTrue,
      );
      expect(
        isForbiddenFailure(CoordinatorLoadException.fromFailure(
          const AuthFailure(
            message: 'x',
            code: 403,
            errorCode: 'ACTING_FOR_FORBIDDEN',
          ),
        )),
        isFalse,
      );
      expect(
        isForbiddenFailure(CoordinatorLoadException.fromFailure(
          const ServerFailure(message: 'x', code: 500),
        )),
        isFalse,
      );
    });
  });

  testWidgets('ForbiddenView is the shared restricted-access state',
      (tester) async {
    await pumpFamilyApp(
      tester,
      overrides: const [],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: ForbiddenView()),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(SacErrorState), findsOneWidget);
    expect(find.text('Acceso restringido'), findsOneWidget);
  });
}
