import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/investiture_requests/data/datasources/investiture_requests_remote_data_source.dart';
import 'package:sacdia_app/features/investiture_requests/data/repositories/investiture_requests_repository_impl.dart';

import 'presentation/investiture_test_harness.dart';

class _ThrowingDataSource implements InvestitureRequestsRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('raw internal detail');
}

class _CodedDataSource implements InvestitureRequestsRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw AuthException(
        message: 'sin permiso',
        code: 403,
        errorCode: 'INVESTITURE_REQUEST_FORBIDDEN',
      );
}

void main() {
  setUpAll(initInvestitureTestEnv);

  test('an unexpected error becomes a generic message, not its raw text',
      () async {
    final repo = InvestitureRequestsRepositoryImpl(
        remoteDataSource: _ThrowingDataSource());

    final result = await repo.getOwnHistory();

    final failure = result.fold((f) => f, (_) => null);
    expect(failure, isA<UnexpectedFailure>());
    expect(failure!.message, tr('investiture_requests.errors.generic'));
    expect(failure.message, isNot(contains('raw internal detail')));
  });

  test('the backend error code is kept on the failure', () async {
    final repo =
        InvestitureRequestsRepositoryImpl(remoteDataSource: _CodedDataSource());

    final result = await repo.getOwnHistory();

    final failure = result.fold((f) => f, (_) => null);
    expect(failure, isA<AuthFailure>());
    expect(failure!.errorCode, 'INVESTITURE_REQUEST_FORBIDDEN');
  });
}
