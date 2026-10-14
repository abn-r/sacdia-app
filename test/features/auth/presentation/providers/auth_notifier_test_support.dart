import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/notifications/push_notification_service.dart';
import 'package:sacdia_app/core/storage/secure_storage.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/notifications/domain/entities/notification_item.dart';
import 'package:sacdia_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fakes y builder compartidos por los tests de `AuthNotifier`.

class FakeSecureStorage implements SecureStorage {
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

/// Repositorio sin sesión: `hasLocalToken` es false, así que
/// `AuthNotifier.build()` resuelve a `null`. Los tests sobreescriben solo
/// los métodos que ejercitan.
class FakeAuthRepository implements AuthRepository {
  @override
  Stream<bool> get authStateChanges => Stream.value(false);

  @override
  Future<bool> hasLocalToken() async => false;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> deleteAccount(DeleteAccountReauth reauth) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<SocialProvider>>> getConnectedProviders() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, bool>> getCompletionStatus() =>
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

class FakeNotificationsRepository implements NotificationsRepository {
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

class FakePushNotificationService extends PushNotificationService {
  FakePushNotificationService({
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

/// Arma un `ProviderContainer` con el repositorio y los colaboradores
/// falsos. Es async porque `SharedPreferences.getInstance()` lo es; los tests
/// que necesiten valores previos llaman a
/// `SharedPreferences.setMockInitialValues` antes o pasan [prefs]/[storage].
Future<ProviderContainer> buildAuthContainer({
  required AuthRepository repo,
  FakeSecureStorage? storage,
  SharedPreferences? prefs,
}) async {
  final resolvedPrefs = prefs ??
      await (() async {
        SharedPreferences.setMockInitialValues({});
        return SharedPreferences.getInstance();
      })();
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      secureStorageProvider.overrideWithValue(storage ?? FakeSecureStorage()),
      sharedPreferencesProvider.overrideWithValue(resolvedPrefs),
      notificationsRepositoryProvider
          .overrideWithValue(FakeNotificationsRepository()),
      pushNotificationServiceProvider.overrideWith(
        (ref) => FakePushNotificationService(ref: ref, prefs: resolvedPrefs),
      ),
    ],
  );
}
