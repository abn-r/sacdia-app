import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage implements SecureStorage {
  final _store = <String, String>{};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<bool> contains(String key) async => _store.containsKey(key);

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<Map<String, String>> readAll() async => Map.unmodifiable(_store);
}

class _OfflineAuthRepository implements AuthRepository {
  @override
  Stream<bool> get authStateChanges => Stream.value(true);

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Left(NetworkFailure(message: 'offline'));

  @override
  Future<Either<Failure, void>> deleteAccount(String password) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, bool>> getCompletionStatus() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> handleOAuthCallback({
    required String sessionToken,
    required String provider,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> resetPassword(String email) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> signInWithApple() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> signOut() => throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String paternalSurname,
    required String maternalSurname,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> switchContext(String assignmentId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> updatePassword(
    String currentPassword,
    String newPassword,
  ) =>
      throw UnimplementedError();
}

class _FakeNotificationsRepository implements NotificationsRepository {
  @override
  Future<
          Either<Failure,
              ({List<NotificationItem> items, int total, int totalPages})>>
      getHistory({
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  }) async =>
          const Right((items: [], total: 0, totalPages: 1));

  @override
  Future<Either<Failure, int>> getUnreadCount() async => const Right(0);

  @override
  Future<Either<Failure, int>> markAllAsRead() async => const Right(0);

  @override
  Future<Either<Failure, void>> markAsRead(String deliveryId) async =>
      const Right(null);
}

class _FakePushNotificationService extends PushNotificationService {
  _FakePushNotificationService({
    required super.ref,
    required SharedPreferences prefs,
  }) : super(
          dio: Dio(),
          prefs: prefs,
          navigatorKey: GlobalKey<NavigatorState>(),
        );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> unregisterToken() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  test('restores permissions and active club context from offline auth cache',
      () async {
    SharedPreferences.setMockInitialValues({
      'cached_post_register_complete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = _FakeSecureStorage();
    await storage.write('cached_user_id', 'user-1');
    await storage.write('cached_user_email', 'elena@example.com');
    await storage.write('cached_user_name', 'Elena');
    await storage.write('cached_active_assignment_id', 'assignment-1');
    await storage.write('cached_active_role_name', 'director');
    await storage.write('cached_active_club_type', 'Conquistadores');
    await storage.write(
      'cached_active_permissions',
      '["dashboard:read","classes:read"]',
    );
    await storage.write('cached_active_club_id', '10');
    await storage.write('cached_active_section_id', '20');
    await storage.write('cached_active_club_type_id', '1');

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_OfflineAuthRepository()),
        secureStorageProvider.overrideWithValue(storage),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationsRepositoryProvider
            .overrideWithValue(_FakeNotificationsRepository()),
        pushNotificationServiceProvider.overrideWith(
          (ref) => _FakePushNotificationService(ref: ref, prefs: prefs),
        ),
      ],
    );
    addTearDown(container.dispose);

    final user = await container.read(authNotifierProvider.future);

    expect(
      user?.authorization?.effectivePermissions,
      containsAll(['dashboard:read', 'classes:read']),
    );
    expect(user?.authorization?.activeGrant?.clubId, 10);
    expect(user?.authorization?.activeGrant?.sectionId, 20);
    expect(user?.authorization?.activeGrant?.clubTypeId, 1);

    final bootstrapState = await container.read(appBootstrapProvider.future);
    expect(bootstrapState, isA<AppBootstrapReady>());
  }, timeout: const Timeout(Duration(seconds: 15)));
}
