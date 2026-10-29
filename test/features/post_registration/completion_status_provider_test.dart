import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/domain/repositories/post_registration_repository.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';

class _SwitchableAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => _user('user-a');

  void switchTo(String id) => state = AsyncValue.data(_user(id));
}

UserEntity _user(String id) => UserEntity(
      id: id,
      email: '$id@example.com',
      name: id,
      postRegisterComplete: false,
    );

class _FakeRepository implements PostRegistrationRepository {
  final Map<String, CompletionStatus> statusByUser;
  final String Function() currentUserId;

  _FakeRepository(this.statusByUser, this.currentUserId);

  @override
  Future<Either<Failure, CompletionStatus>> getCompletionStatus({
    RequestCancelToken? cancelToken,
  }) async =>
      Right(statusByUser[currentUserId()]!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('completion status is refetched when the signed-in user changes',
      () async {
    late ProviderContainer container;
    String currentUserId() =>
        container.read(authNotifierProvider).valueOrNull!.id;

    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_SwitchableAuthNotifier.new),
        postRegistrationRepositoryProvider.overrideWith(
          (ref) => _FakeRepository(
            const {
              'user-a': CompletionStatus(
                isComplete: false,
                currentStep: 3,
                photoComplete: true,
                personalInfoComplete: true,
                clubSelectionComplete: false,
              ),
              'user-b': CompletionStatus(
                isComplete: false,
                currentStep: 1,
                photoComplete: false,
                personalInfoComplete: false,
                clubSelectionComplete: false,
              ),
            },
            currentUserId,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.future);
    expect((await container.read(completionStatusProvider.future))?.currentStep,
        3);

    (container.read(authNotifierProvider.notifier) as _SwitchableAuthNotifier)
        .switchTo('user-b');

    expect((await container.read(completionStatusProvider.future))?.currentStep,
        1);
  });

  test('a failure surfaces as an error (never a null "no status")', () async {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_SwitchableAuthNotifier.new),
        postRegistrationRepositoryProvider.overrideWith(
          (ref) => _FailingRepository(
            const ServerFailure(
              message: 'Post-registration has not been started',
              code: 400,
              errorCode: 'AUTH_POST_REGISTRATION_NOT_STARTED',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);

    await expectLater(
      container.read(completionStatusProvider.future),
      throwsA(
        isA<ServerFailure>().having(
          (f) => f.errorCode,
          'errorCode',
          'AUTH_POST_REGISTRATION_NOT_STARTED',
        ),
      ),
    );
  });
}

class _FailingRepository implements PostRegistrationRepository {
  _FailingRepository(this.failure);

  final Failure failure;

  @override
  Future<Either<Failure, CompletionStatus>> getCompletionStatus({
    RequestCancelToken? cancelToken,
  }) async =>
      Left(failure);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
