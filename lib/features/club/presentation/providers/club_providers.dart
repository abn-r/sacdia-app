import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/datasources/club_remote_data_source.dart';
import '../../data/repositories/club_repository_impl.dart';
import '../../domain/entities/club_info.dart';
import '../../domain/repositories/club_repository.dart';
import '../../domain/usecases/get_club_info.dart';
import '../../domain/usecases/get_club_section.dart';
import '../../domain/usecases/update_club_section.dart';

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

final getClubInfoUseCaseProvider = Provider<GetClubInfo>((ref) {
  return GetClubInfo(ref.read(clubRepositoryProvider));
});

final getClubSectionUseCaseProvider = Provider<GetClubSection>((ref) {
  return GetClubSection(ref.read(clubRepositoryProvider));
});

// ── Club info by ID (for detail view) ────────────────────────────────────────

/// Obtiene la información básica del club contenedor por su UUID.
final clubInfoProvider =
    FutureProvider.autoDispose.family<ClubInfo, String>((ref, clubId) async {
  final useCase = ref.read(getClubInfoUseCaseProvider);
  final result = await useCase(GetClubInfoParams(clubId: clubId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (club) => club,
  );
});

final updateClubSectionUseCaseProvider = Provider<UpdateClubSection>((ref) {
  return UpdateClubSection(ref.read(clubRepositoryProvider));
});

// ── Role helpers ──────────────────────────────────────────────────────────────

/// Roles que permiten editar la información del club.
const _editableRoles = {'director', 'subdirector', 'deputy_director'};

/// Devuelve true si el usuario actual puede editar el club.
///
/// Lee los roles del metadata del usuario autenticado.
final canEditClubProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authState = await ref.watch(authNotifierProvider.future);
  if (authState == null) return false;

  return canByPermissionOrLegacyRole(
    authState,
    requiredPermissions: const {
      'clubs:update',
      'club_sections:update',
    },
    legacyRoles: _editableRoles,
  );
});

// ── Club section provider (read) ─────────────────────────────────────────────

/// Carga la sección de club del usuario actual.
/// Depende de [clubContextProvider] del módulo de miembros (fuente de verdad del contexto).
final currentClubSectionProvider =
    FutureProvider.autoDispose<ClubSection?>((ref) async {
  final context = await ref.watch(clubContextProvider.future);
  if (context == null) return null;

  final useCase = ref.read(getClubSectionUseCaseProvider);
  final result = await useCase(
    GetClubSectionParams(
      clubId: context.clubId.toString(),
      sectionId: context.sectionId,
    ),
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (section) => section,
  );
});

// ── Update notifier ───────────────────────────────────────────────────────────

/// Estado para la operación de actualización de la sección de club.
class UpdateClubState {
  final bool isLoading;
  final ClubSection? updatedSection;
  final String? errorMessage;

  const UpdateClubState({
    this.isLoading = false,
    this.updatedSection,
    this.errorMessage,
  });

  UpdateClubState copyWith({
    bool? isLoading,
    ClubSection? updatedSection,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UpdateClubState(
      isLoading: isLoading ?? this.isLoading,
      updatedSection: updatedSection ?? this.updatedSection,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Notifier para gestionar la actualización de la sección de club.
class UpdateClubNotifier extends AutoDisposeNotifier<UpdateClubState> {
  @override
  UpdateClubState build() => const UpdateClubState();

  /// Guarda los cambios de la sección de club.
  Future<bool> save({
    required String clubId,
    required int sectionId,
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

    final useCase = ref.read(updateClubSectionUseCaseProvider);
    final result = await useCase(
      UpdateClubSectionParams(
        clubId: clubId,
        sectionId: sectionId,
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
      (section) {
        state = state.copyWith(
          isLoading: false,
          updatedSection: section,
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
