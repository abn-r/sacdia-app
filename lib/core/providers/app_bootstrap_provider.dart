import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/principal_info.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';
import '../../providers/storage_provider.dart';
import '../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../features/honors/presentation/providers/honors_providers.dart';
import '../../features/members/presentation/providers/members_providers.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/enrollment/presentation/providers/enrollment_providers.dart';
import '../../features/activities/presentation/providers/activities_providers.dart';
import '../../features/classes/presentation/providers/classes_providers.dart';
import '../../features/club/presentation/providers/club_providers.dart';
import '../../features/notifications/presentation/providers/notifications_providers.dart';

/// User-specific providers that must be invalidated on logout or nuclear reset.
/// Single source of truth — used by both [AppBootstrapNotifier._nuclearReset]
/// and [clearUserStateOnLogout] in logout_cleanup.dart.
final List<ProviderOrFamily> userSpecificProviders = [
  dashboardNotifierProvider,
  userHonorsProvider,
  userClassesProvider,
  clubContextProvider,
  currentClubSectionProvider,
  profileNotifierProvider,
  currentEnrollmentProvider,
  clubActivitiesProvider,
  notificationsInboxProvider,
];

// ─── State ───────────────────────────────────────────────────────────────────

/// Sealed hierarchy for bootstrap states.
/// Loading is represented by [AsyncLoading] from Riverpod's [AsyncValue].
sealed class AppBootstrapState {
  const AppBootstrapState();
}

/// Authorization validated — safe to navigate to dashboard.
class AppBootstrapReady extends AppBootstrapState {
  const AppBootstrapReady();
}

/// Why bootstrap could not reach [AppBootstrapReady].
enum AppBootstrapErrorKind {
  /// `/auth/me` did not deliver an authorization snapshot (network, cache
  /// miss, unexpected payload). Retrying may fix it.
  loadFailed,

  /// `/auth/me` answered with an authorization snapshot that has no grants
  /// and no permissions: the account simply has no role yet. Not a failure.
  noRole,
}

/// Auto-retries exhausted — splash shows retry button.
class AppBootstrapError extends AppBootstrapState {
  final String message;
  final int attemptCount;
  final AppBootstrapErrorKind kind;
  const AppBootstrapError(
    this.message,
    this.attemptCount, {
    this.kind = AppBootstrapErrorKind.loadFailed,
  });
}

/// No authenticated user, or nuclear reset completed — redirect to login.
class AppBootstrapUnauthenticated extends AppBootstrapState {
  const AppBootstrapUnauthenticated();
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AppBootstrapNotifier extends AsyncNotifier<AppBootstrapState> {
  int _autoRetryCount = 0;
  bool _inRetryLoop = false;

  static const _maxAutoRetries = 3;
  static const _tag = 'AppBootstrap';

  @override
  Future<AppBootstrapState> build() async {
    // React to external auth changes (login, logout, context switch).
    // Guard: skip during retry loop to prevent self-cancellation.
    ref.listen(authNotifierProvider, (_, __) {
      if (!_inRetryLoop) {
        _autoRetryCount = 0;
        ref.invalidateSelf();
      }
    });

    return _validateAndRetry();
  }

  Future<AppBootstrapState> _validateAndRetry() async {
    UserEntity? user;
    try {
      user = await ref.read(authNotifierProvider.future);
    } catch (e, st) {
      AppLogger.e('Auth future threw: $e', tag: _tag, error: e, stackTrace: st);
      return AppBootstrapError(
          tr('core.bootstrap.unexpected_session_error'), 0);
    }

    if (user == null) {
      _autoRetryCount = 0;
      return const AppBootstrapUnauthenticated();
    }

    if (_isValidAuthorization(user)) {
      _autoRetryCount = 0;
      return const AppBootstrapReady();
    }

    // Authorization incomplete — enter auto-retry loop.
    UserEntity lastUser = user;
    _inRetryLoop = true;
    try {
      for (var attempt = 1; attempt <= _maxAutoRetries; attempt++) {
        _autoRetryCount = attempt;
        final delay = Duration(seconds: attempt - 1); // 0s, 1s, 2s
        if (delay > Duration.zero) await Future.delayed(delay);

        AppLogger.d('Auto-retry $attempt/$_maxAutoRetries', tag: _tag);

        ref.invalidate(authNotifierProvider);
        UserEntity? freshUser;
        try {
          freshUser = await ref.read(authNotifierProvider.future);
        } catch (e, st) {
          AppLogger.e('Retry auth future threw: $e',
              tag: _tag, error: e, stackTrace: st);
          continue; // Skip to next retry attempt
        }

        if (freshUser != null) lastUser = freshUser;
        if (freshUser != null && _isValidAuthorization(freshUser)) {
          _autoRetryCount = 0;
          return const AppBootstrapReady();
        }
      }
    } finally {
      _inRetryLoop = false;
    }

    AppLogger.w('Auto-retries exhausted', tag: _tag);
    if (hasNoAssignedRole(lastUser)) {
      return AppBootstrapError(
        tr('core.bootstrap.no_role_assigned'),
        _autoRetryCount,
        kind: AppBootstrapErrorKind.noRole,
      );
    }
    return AppBootstrapError(
      tr('core.bootstrap.permissions_load_failed'),
      _autoRetryCount,
    );
  }

  /// True when `/auth/me` delivered an authorization snapshot that is empty:
  /// no global roles, no club assignments and no permissions. A null snapshot
  /// means it was not loaded (e.g. offline without cache) — that is a load
  /// failure, not "no role".
  @visibleForTesting
  static bool hasNoAssignedRole(UserEntity user) {
    final auth = user.authorization;
    if (auth == null) return false;
    return auth.globalGrants.isEmpty &&
        auth.clubAssignments.isEmpty &&
        auth.effectivePermissions.isEmpty;
  }

  /// Checks that the user has non-empty permissions and roles.
  bool _isValidAuthorization(UserEntity user) {
    // Una cuenta restringida (sin fecha de nacimiento o de un tipo que la app
    // no conoce) no tiene permisos de club que validar: solo ve el
    // post-registro o su pantalla informativa. Exigirlos la dejaría en el
    // reintento del splash en lugar de llevarla a su destino.
    if (user.isRestrictedAccount) return true;
    // Un teléfono vinculado no tiene roles ni permisos de club que validar: ve
    // su propia cáscara (clases, agenda, avisos) y el servidor decide el resto.
    if (user.isLinkedDevice) return true;
    // Un adolescente pendiente de tutor no tiene roles de club hasta que su
    // tutor se verifique: el servidor no se los da. Ve su pantalla de estado y
    // el post-registro; exigirle permisos lo dejaba en el aviso de "sin rol" y
    // el reintento lo devolvía al login.
    if (user.mode == AccountMode.teenPending) return true;
    final auth = user.authorization;
    if (auth == null) return false;
    if (auth.effectivePermissions.isEmpty) return false;
    if (auth.resolvedRoleNames.isEmpty) return false;
    return true;
  }

  /// Manual retry triggered by splash "Reintentar" button.
  /// One attempt — if it fails, nuclear reset and redirect to login.
  Future<void> retry() async {
    AppLogger.d('Manual retry triggered', tag: _tag);
    state = const AsyncLoading();

    _inRetryLoop = true;
    try {
      ref.invalidate(authNotifierProvider);
      final user = await ref.read(authNotifierProvider.future);

      if (user != null && _isValidAuthorization(user)) {
        _autoRetryCount = 0;
        state = const AsyncData(AppBootstrapReady());
        return;
      }
    } finally {
      _inRetryLoop = false;
    }

    AppLogger.w('Manual retry failed — nuclear reset', tag: _tag);
    await _nuclearReset();
    state = const AsyncData(AppBootstrapUnauthenticated());
  }

  /// Clears all local state and invalidates every user-specific provider.
  Future<void> _nuclearReset() async {
    AppLogger.w('Clearing all user state', tag: _tag);

    final secureStorage = ref.read(secureStorageProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    // Clear all secure storage keys — continue even if individual deletes fail.
    final keysToDelete = [
      AppConstants.tokenKey,
      AppConstants.refreshTokenKey,
      AppConstants.expiresAtKey,
      AppConstants.tokenTypeKey,
      AppConstants.sessionModeKey,
      AppConstants.cachedUserId,
      AppConstants.cachedUserEmail,
      AppConstants.cachedUserName,
      AppConstants.cachedUserAvatar,
      AppConstants.cachedActiveAssignmentId,
      AppConstants.cachedActiveRoleName,
      AppConstants.cachedActiveClubName,
      AppConstants.cachedActiveClubType,
      AppConstants.cachedActivePermissions,
      AppConstants.cachedActiveClubId,
      AppConstants.cachedActiveSectionId,
      AppConstants.cachedActiveClubTypeId,
      'cached_post_register_complete',
    ];

    await Future.wait(
      keysToDelete.map((key) => secureStorage.delete(key).catchError((e) {
            AppLogger.e('Failed to delete $key: $e', tag: _tag);
          })),
    );

    // SharedPreferences — await to ensure flush before state transition.
    await prefs.remove('cached_post_register_complete');
    await prefs.remove('user_manually_logged_out');

    // Invalidate all user-specific providers.
    for (final provider in userSpecificProviders) {
      ref.invalidate(provider);
    }
    ref.invalidate(authNotifierProvider);
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final appBootstrapProvider =
    AsyncNotifierProvider<AppBootstrapNotifier, AppBootstrapState>(() {
  return AppBootstrapNotifier();
});
