import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/domain/repositories/activities_repository.dart';
import 'package:sacdia_app/features/activities/domain/usecases/get_club_activities.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _FakeGetClubActivities implements GetClubActivities {
  int calls = 0;

  @override
  ActivitiesRepository get repository => throw UnimplementedError();

  @override
  Future<Either<Failure, List<Activity>>> call(
    GetClubActivitiesParams params, {
    RequestCancelToken? cancelToken,
  }) async {
    calls += 1;
    return const Right(<Activity>[]);
  }
}

void main() {
  test('clubActivitiesProvider does not fetch after logout', () async {
    final fakeGetClubActivities = _FakeGetClubActivities();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(null)),
        getClubActivitiesProvider.overrideWithValue(fakeGetClubActivities),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.future);

    final activities = await container.read(
      clubActivitiesProvider(const ClubActivitiesParams(clubId: 1)).future,
    );

    expect(activities, isEmpty);
    expect(fakeGetClubActivities.calls, 0);
  });
}
