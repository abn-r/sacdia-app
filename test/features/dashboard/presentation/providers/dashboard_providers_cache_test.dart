import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/usecase.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/data/models/dashboard_summary_model.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:sacdia_app/features/dashboard/domain/usecases/get_dashboard_data.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

class _FakeGetDashboardSummary implements GetDashboardSummary {
  _FakeGetDashboardSummary({
    required this.result,
    this.resultByAssignment,
    this.resolveAssignment,
  });

  final Either<Failure, DashboardSummary> result;
  final Map<String, DashboardSummary>? resultByAssignment;
  final String? Function()? resolveAssignment;

  int calls = 0;

  @override
  Future<Either<Failure, DashboardSummary>> call(
    NoParams params, {
    Object? cancelToken,
  }) async {
    calls++;
    if (resultByAssignment != null) {
      final assignment = resolveAssignment?.call();
      if (assignment != null && resultByAssignment!.containsKey(assignment)) {
        return Right(resultByAssignment![assignment]!);
      }
    }
    return result;
  }

  @override
  DashboardRepository get repository => throw UnimplementedError(
        'repository is intentionally unused in tests',
      );
}

class _ControlledGetDashboardSummary implements GetDashboardSummary {
  int calls = 0;
  final Completer<void> firstCallStarted = Completer<void>();
  final List<Completer<Either<Failure, DashboardSummary>>> _pendingCalls = [];

  @override
  Future<Either<Failure, DashboardSummary>> call(
    NoParams params, {
    Object? cancelToken,
  }) async {
    calls++;
    if (!firstCallStarted.isCompleted) {
      firstCallStarted.complete();
    }

    final completer = Completer<Either<Failure, DashboardSummary>>();
    _pendingCalls.add(completer);
    return completer.future;
  }

  void completeAll(Either<Failure, DashboardSummary> response) {
    for (final call in _pendingCalls) {
      if (!call.isCompleted) {
        call.complete(response);
      }
    }
  }

  @override
  DashboardRepository get repository => throw UnimplementedError(
        'repository is intentionally unused in tests',
      );
}

Future<ProviderContainer> _buildDashboardContainer({
  required _FakeAuthNotifier authNotifier,
  required GetDashboardSummary useCase,
  required Map<String, Object> initialPrefs,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();

  return ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => authNotifier),
      getDashboardSummaryProvider.overrideWithValue(useCase),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

UserEntity _buildUser({
  required String userId,
  required String activeAssignmentId,
}) {
  return UserEntity(
    id: userId,
    email: '$userId@local.test',
    name: 'Tester',
    postRegisterComplete: true,
    authorization: AuthorizationSnapshot(
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: activeAssignmentId,
          roleName: 'member',
        ),
      ],
      activeAssignmentId: activeAssignmentId,
    ),
  );
}

DashboardSummary _summary({
  required String userName,
  String? clubName,
}) {
  return DashboardSummary(
    userName: userName,
    userAvatar: null,
    clubName: clubName,
    clubType: 'Conquistadores',
    userRole: 'member',
    currentClassName: 'Guías',
    currentClassInvestitureStatus: 'active',
    currentClassId: 1,
    classProgress: 0.2,
    honorsCompleted: 2,
    honorsInProgress: 1,
    upcomingActivities: const [],
  );
}

String _dashboardCacheKey({
  required String userId,
  required String assignmentId,
}) {
  return '${AppConstants.dashboardSummaryCacheKeyPrefix}_${userId}_assignment_$assignmentId';
}

Map<String, dynamic> _summaryJson(DashboardSummary summary) {
  return DashboardSummaryModel(
    userName: summary.userName,
    userAvatar: summary.userAvatar,
    clubName: summary.clubName,
    clubType: summary.clubType,
    userRole: summary.userRole,
    currentClassName: summary.currentClassName,
    currentClassInvestitureStatus: summary.currentClassInvestitureStatus,
    currentClassId: summary.currentClassId,
    classProgress: summary.classProgress,
    honorsCompleted: summary.honorsCompleted,
    honorsInProgress: summary.honorsInProgress,
    upcomingActivities: summary.upcomingActivities,
  ).toJson();
}

void main() {
  group('Dashboard summary cache', () {
    test('returns cached summary within TTL without immediate refresh',
        () async {
      final authNotifier = _FakeAuthNotifier(
        _buildUser(userId: 'user-1', activeAssignmentId: 'assign-a'),
      );
      final key = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-a',
      );
      final cached = _summary(userName: 'Ana', clubName: 'Aventura');
      final remote = _summary(userName: 'Ana', clubName: 'Live');
      final useCase = _FakeGetDashboardSummary(result: Right(remote));
      final container = await _buildDashboardContainer(
        authNotifier: authNotifier,
        useCase: useCase,
        initialPrefs: {
          key: jsonEncode(_summaryJson(cached)),
          '${key}_cached_at': DateTime.now().millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(dashboardNotifierProvider.future);

      expect(result?.clubName, equals('Aventura'));
      expect(useCase.calls, equals(0));
    });

    test(
        'returns cached dashboard immediately and refreshes in background'
        ' without blocking the cached result', () async {
      final authNotifier = _FakeAuthNotifier(
        _buildUser(userId: 'user-1', activeAssignmentId: 'assign-a'),
      );
      final key = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-a',
      );
      final cached = _summary(userName: 'Ana', clubName: 'Aventura');
      final remote = _summary(userName: 'Ana', clubName: 'Live');
      final useCase = _ControlledGetDashboardSummary();
      final container = await _buildDashboardContainer(
        authNotifier: authNotifier,
        useCase: useCase,
        initialPrefs: {
          key: jsonEncode(_summaryJson(cached)),
          '${key}_cached_at': DateTime.now()
              .subtract(const Duration(seconds: 45))
              .millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      final resultFuture = container.read(dashboardNotifierProvider.future);
      bool buildCompleted = false;
      unawaited(resultFuture.then((_) => buildCompleted = true));

      await useCase.firstCallStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(buildCompleted, isTrue);
      expect(useCase.calls, equals(1));

      useCase.completeAll(Right(remote));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(dashboardNotifierProvider).value?.clubName,
          equals('Live'));
    });

    test('does not block on background refresh failure', () async {
      final authNotifier = _FakeAuthNotifier(
        _buildUser(userId: 'user-1', activeAssignmentId: 'assign-a'),
      );
      final key = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-a',
      );
      final cached = _summary(userName: 'Ana', clubName: 'Cached');
      final useCase = _ControlledGetDashboardSummary();
      final container = await _buildDashboardContainer(
        authNotifier: authNotifier,
        useCase: useCase,
        initialPrefs: {
          key: jsonEncode(_summaryJson(cached)),
          '${key}_cached_at': DateTime.now()
              .subtract(const Duration(seconds: 45))
              .millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      final resultFuture = container.read(dashboardNotifierProvider.future);
      bool buildCompleted = false;
      unawaited(resultFuture.then((_) => buildCompleted = true));

      await useCase.firstCallStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(buildCompleted, isTrue);
      expect(useCase.calls, equals(1));
      expect(container.read(dashboardNotifierProvider).value?.clubName,
          equals('Cached'));

      useCase.completeAll(
        left(
          const ServerFailure(message: 'server down'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(dashboardNotifierProvider);
      expect(state.hasError, isFalse);
      expect(state.value?.clubName, equals('Cached'));
    });

    test('throttles background refresh attempts after a transient failure',
        () async {
      final authNotifier = _FakeAuthNotifier(
        _buildUser(userId: 'user-1', activeAssignmentId: 'assign-a'),
      );
      final key = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-a',
      );
      final cached = _summary(userName: 'Ana', clubName: 'Cached');
      final useCase = _ControlledGetDashboardSummary();
      final container = await _buildDashboardContainer(
        authNotifier: authNotifier,
        useCase: useCase,
        initialPrefs: {
          key: jsonEncode(_summaryJson(cached)),
          '${key}_cached_at': DateTime.now()
              .subtract(const Duration(seconds: 45))
              .millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      await container.read(dashboardNotifierProvider.future);
      await useCase.firstCallStarted.future;
      useCase.completeAll(
        left(
          const ServerFailure(message: 'server down'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(useCase.calls, equals(1));

      container.invalidate(dashboardNotifierProvider);
      final cachedAgain =
          await container.read(dashboardNotifierProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(cachedAgain?.clubName, equals('Cached'));
      expect(useCase.calls, equals(1));
    });

    test(
        'does not schedule duplicate background refresh for the same cache key',
        () async {
      final authNotifier = _FakeAuthNotifier(
        _buildUser(userId: 'user-1', activeAssignmentId: 'assign-a'),
      );
      final key = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-a',
      );
      final cached = _summary(userName: 'Ana', clubName: 'Cached');
      final useCase = _ControlledGetDashboardSummary();
      final container = await _buildDashboardContainer(
        authNotifier: authNotifier,
        useCase: useCase,
        initialPrefs: {
          key: jsonEncode(_summaryJson(cached)),
          '${key}_cached_at': DateTime.now()
              .subtract(const Duration(seconds: 45))
              .millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      final resultFuture = container.read(dashboardNotifierProvider.future);
      await useCase.firstCallStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(resultFuture, isA<Future<DashboardSummary?>>());
      expect(useCase.calls, equals(1));

      container.invalidate(dashboardNotifierProvider);
      await container.read(dashboardNotifierProvider.future);

      await Future<void>.delayed(Duration.zero);
      expect(useCase.calls, equals(1));
      useCase.completeAll(Right(cached));
      await Future<void>.delayed(Duration.zero);
    });

    test('falls back to API when TTL expires', () async {
      final authNotifier = _FakeAuthNotifier(
        _buildUser(userId: 'user-1', activeAssignmentId: 'assign-a'),
      );
      final key = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-a',
      );
      final cached = _summary(userName: 'Ana', clubName: 'Old');
      final remote = _summary(userName: 'Ana', clubName: 'Fresh');
      final useCase = _FakeGetDashboardSummary(result: Right(remote));
      final container = await _buildDashboardContainer(
        authNotifier: authNotifier,
        useCase: useCase,
        initialPrefs: {
          key: jsonEncode(_summaryJson(cached)),
          '${key}_cached_at': DateTime.now()
              .subtract(const Duration(minutes: 2))
              .millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(dashboardNotifierProvider.future);

      expect(result?.clubName, equals('Fresh'));
      expect(useCase.calls, equals(1));
    });

    test('falls back to API when cached dashboard JSON is invalid', () async {
      final authNotifier = _FakeAuthNotifier(
        _buildUser(userId: 'user-1', activeAssignmentId: 'assign-a'),
      );
      final key = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-a',
      );
      final remote = _summary(userName: 'Ana', clubName: 'Recovered');
      final useCase = _FakeGetDashboardSummary(result: Right(remote));
      final container = await _buildDashboardContainer(
        authNotifier: authNotifier,
        useCase: useCase,
        initialPrefs: {
          key: 'invalid-json',
          '${key}_cached_at': DateTime.now().millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(dashboardNotifierProvider.future);

      expect(result?.clubName, equals('Recovered'));
      expect(useCase.calls, equals(1));
    });

    test('scopes dashboard cache by userId and activeAssignmentId', () async {
      final authNotifier = _FakeAuthNotifier(
        _buildUser(userId: 'user-1', activeAssignmentId: 'assign-a'),
      );
      final keyA = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-a',
      );
      final keyB = _dashboardCacheKey(
        userId: 'user-1',
        assignmentId: 'assign-b',
      );
      final summaryA = _summary(userName: 'Ana', clubName: 'Club A');
      final summaryB = _summary(userName: 'Ana', clubName: 'Club B');
      final useCase = _FakeGetDashboardSummary(
        result: Right(summaryA),
        resultByAssignment: {
          'assign-a': summaryA,
          'assign-b': summaryB,
        },
        resolveAssignment: () =>
            authNotifier.user?.authorization?.activeAssignmentId,
      );
      final container = await _buildDashboardContainer(
        authNotifier: authNotifier,
        useCase: useCase,
        initialPrefs: {
          keyA: jsonEncode(_summaryJson(summaryA)),
          '${keyA}_cached_at': DateTime.now().millisecondsSinceEpoch,
          keyB: jsonEncode(_summaryJson(summaryB)),
          '${keyB}_cached_at': DateTime.now().millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      final resultA = await container.read(dashboardNotifierProvider.future);
      expect(resultA?.clubName, equals('Club A'));
      expect(useCase.calls, equals(0));

      authNotifier.user =
          _buildUser(userId: 'user-1', activeAssignmentId: 'assign-b');
      container.invalidate(authNotifierProvider);
      container.invalidate(dashboardNotifierProvider);
      final resultB = await container.read(dashboardNotifierProvider.future);
      expect(resultB?.clubName, equals('Club B'));
      expect(useCase.calls, equals(0));
    });
  });
}
