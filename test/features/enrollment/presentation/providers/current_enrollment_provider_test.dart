import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
import 'package:sacdia_app/features/enrollment/domain/usecases/get_current_enrollment.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

class _FailingUseCase extends Fake implements GetCurrentEnrollment {
  @override
  Future<Either<Failure, Enrollment?>> call(
    GetCurrentEnrollmentParams params, {
    dynamic cancelToken,
  }) async =>
      const Left(ServerFailure(message: 'forbidden', code: 403));
}

/// A counselor gets 403 on /enrollments/current. Treating that as "no
/// enrollment" showed "the club has not enrolled this year" for a club that
/// had. A failed lookup must surface as an error, not as null.
void main() {
  test('a failed lookup is an error, not "no enrollment"', () async {
    final container = ProviderContainer(
      overrides: [
        clubContextProvider.overrideWith(
          (ref) async => const ClubContext(
            clubId: 1,
            sectionId: 1,
            roleName: 'counselor',
          ),
        ),
        getCurrentEnrollmentUseCaseProvider.overrideWithValue(
          _FailingUseCase(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(currentEnrollmentProvider.future),
      throwsA(isA<ServerFailure>()),
    );
  });
}
