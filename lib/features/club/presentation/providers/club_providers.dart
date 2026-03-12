import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../miembros/presentation/providers/miembros_providers.dart';
import '../../data/datasources/club_remote_data_source.dart';
import '../../data/repositories/club_repository_impl.dart';
import '../../domain/entities/club_info.dart';
import '../../domain/repositories/club_repository.dart';
import '../../domain/usecases/get_club_instance.dart';
import '../../domain/usecases/update_club_instance.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Data source remoto para el módulo de club.
final clubRemoteDataSourceProvider = Provider<ClubRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);
  return ClubRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);
});

/// Repositorio del módulo de club.
final clubRepositoryProvider = Provider<ClubRepository>((ref) {
  return ClubRepositoryImpl(
    remoteDataSource: ref.read(clubRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use case providers ────────────────────────────────────────────────────────

final getClubInstanceUseCaseProvider = Provider<GetClubInstance>((ref) {
  return GetClubInstance(ref.read(clubRepositoryProvider));
});

final updateClubInstanceUseCaseProvider = Provider<UpdateClubInstance>((ref) {
  return UpdateClubInstance(ref.read(clubRepositoryProvider));
});

// ── Role helpers ──────────────────────────────────────────────────────────────

/// Roles que permiten editar la información del club.
const _editableRoles = {'director', 'subdirector', 'deputy_director'};

/// Devuelve true si el usuario actual puede editar el club.
///
/// Lee los roles del metadata del usuario autenticado.
final canEditClubProvider = FutureProvider<bool>((ref) async {
  final authState = await ref.watch(authNotifierProvider.future);
  if (authState == null) return false;

  return canByPermissionOrLegacyRole(
    authState,
    requiredPermissions: const {
      'clubs:update',
      'club_instances:update',
      'clubs_instances:update',
    },
    legacyRoles: _editableRoles,
  );
});

// ── Club instance provider (read) ─────────────────────────────────────────────

/// Carga la instancia de club del usuario actual.
/// Depende de [clubContextProvider] del módulo de miembros (fuente de verdad del contexto).
final currentClubInstanceProvider =
    FutureProvider.autoDispose<ClubInstance?>((ref) async {
  final context = await ref.watch(clubContextProvider.future);
  if (context == null) return null;

  final useCase = ref.read(getClubInstanceUseCaseProvider);
  final result = await useCase(
    GetClubInstanceParams(
      clubId: context.clubId.toString(),
      instanceType: context.instanceType,
      instanceId: context.instanceId,
    ),
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (instance) => instance,
  );
});

// ── Update notifier ───────────────────────────────────────────────────────────

/// Estado para la operación de actualización de la instancia de club.
class UpdateClubState {
  final bool isLoading;
  final ClubInstance? updatedInstance;
  final String? errorMessage;

  const UpdateClubState({
    this.isLoading = false,
    this.updatedInstance,
    this.errorMessage,
  });

  UpdateClubState copyWith({
    bool? isLoading,
    ClubInstance? updatedInstance,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UpdateClubState(
      isLoading: isLoading ?? this.isLoading,
      updatedInstance: updatedInstance ?? this.updatedInstance,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Notifier para gestionar la actualización de la instancia de club.
class UpdateClubNotifier extends AutoDisposeNotifier<UpdateClubState> {
  @override
  UpdateClubState build() => const UpdateClubState();

  /// Guarda los cambios de la instancia de club.
  Future<bool> save({
    required String clubId,
    required String instanceType,
    required int instanceId,
    String? name,
    String? phone,
    String? email,
    String? website,
    String? logoUrl,
    String? address,
    double? lat,
    double? long,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final useCase = ref.read(updateClubInstanceUseCaseProvider);
    final result = await useCase(
      UpdateClubInstanceParams(
        clubId: clubId,
        instanceType: instanceType,
        instanceId: instanceId,
        name: name,
        phone: phone,
        email: email,
        website: website,
        logoUrl: logoUrl,
        address: address,
        lat: lat,
        long: long,
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (instance) {
        state = state.copyWith(
          isLoading: false,
          updatedInstance: instance,
        );
        return true;
      },
    );
  }

  /// Limpia el estado para reutilizar el notifier.
  void reset() => state = const UpdateClubState();
}

/// Provider del notifier de actualización de club.
final updateClubNotifierProvider =
    NotifierProvider.autoDispose<UpdateClubNotifier, UpdateClubState>(
  UpdateClubNotifier.new,
);
