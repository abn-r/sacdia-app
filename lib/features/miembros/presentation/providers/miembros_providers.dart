import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/miembros_remote_data_source.dart';
import '../../data/repositories/miembros_repository_impl.dart';
import '../../domain/entities/club_member.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/repositories/miembros_repository.dart';
import '../../domain/usecases/assign_club_role.dart';
import '../../domain/usecases/get_club_members.dart';
import '../../domain/usecases/get_join_requests.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider de la fuente de datos remota de miembros
final miembrosRemoteDataSourceProvider =
    Provider<MiembrosRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);
  return MiembrosRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);
});

/// Provider del repositorio de miembros
final miembrosRepositoryProvider = Provider<MiembrosRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final remoteDataSource = ref.read(miembrosRemoteDataSourceProvider);
  return MiembrosRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

// ── Use case providers ────────────────────────────────────────────────────────

final getClubMembersUseCaseProvider = Provider<GetClubMembers>((ref) {
  return GetClubMembers(ref.read(miembrosRepositoryProvider));
});

final getJoinRequestsUseCaseProvider = Provider<GetJoinRequests>((ref) {
  return GetJoinRequests(ref.read(miembrosRepositoryProvider));
});

final assignClubRoleUseCaseProvider = Provider<AssignClubRole>((ref) {
  return AssignClubRole(ref.read(miembrosRepositoryProvider));
});

// ── Context providers — club/instance values ──────────────────────────────────

/// Estado del contexto del club activo (clubId, instanceType, instanceId)
class ClubContext {
  final int clubId;
  final String instanceType;
  final int instanceId;

  const ClubContext({
    required this.clubId,
    required this.instanceType,
    required this.instanceId,
  });
}

/// Provider del contexto del club activo.
/// El clubId / instanceId se obtienen desde el perfil del usuario autenticado.
/// Para la iteración inicial se usan valores derivados de la sesión.
final clubContextProvider = FutureProvider<ClubContext?>((ref) async {
  final authState = await ref.watch(authNotifierProvider.future);
  if (authState == null) return null;

  // El contexto del club viene en el metadata del usuario o en el perfil.
  // Por ahora leemos desde el metadata del UserEntity.
  final metadata = authState.metadata;
  if (metadata == null) return null;

  final clubData = metadata['club'] as Map<String, dynamic>?;
  final clubId = clubData?['club_id'];
  final instanceId = clubData?['instance_id'] ?? clubData?['id'];
  final instanceType = clubData?['club_type'] as String? ?? 'conquistadores';

  if (clubId == null || instanceId == null) return null;

  return ClubContext(
    clubId: clubId is int ? clubId : int.tryParse(clubId.toString()) ?? 0,
    instanceType: instanceType,
    instanceId:
        instanceId is int ? instanceId : int.tryParse(instanceId.toString()) ?? 0,
  );
});

// ── Members state ─────────────────────────────────────────────────────────────

/// Filtros de búsqueda para miembros
class MemberFilters {
  final String searchQuery;
  final String? classFilter;
  final String? roleFilter;
  final bool? enrolledFilter;

  const MemberFilters({
    this.searchQuery = '',
    this.classFilter,
    this.roleFilter,
    this.enrolledFilter,
  });

  MemberFilters copyWith({
    String? searchQuery,
    String? classFilter,
    bool clearClass = false,
    String? roleFilter,
    bool clearRole = false,
    bool? enrolledFilter,
    bool clearEnrolled = false,
  }) {
    return MemberFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      classFilter: clearClass ? null : (classFilter ?? this.classFilter),
      roleFilter: clearRole ? null : (roleFilter ?? this.roleFilter),
      enrolledFilter:
          clearEnrolled ? null : (enrolledFilter ?? this.enrolledFilter),
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      classFilter != null ||
      roleFilter != null ||
      enrolledFilter != null;

  /// Filtra la lista de miembros según los criterios activos
  List<ClubMember> applyTo(List<ClubMember> members) {
    return members.where((m) {
      // Búsqueda por nombre
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final name = m.fullName.toLowerCase();
        if (!name.contains(query)) return false;
      }
      // Filtro por clase
      if (classFilter != null && classFilter!.isNotEmpty) {
        final memberClass = (m.currentClass ?? '').toLowerCase();
        if (!memberClass.contains(classFilter!.toLowerCase())) return false;
      }
      // Filtro por rol
      if (roleFilter != null && roleFilter!.isNotEmpty) {
        final memberRole = (m.clubRole ?? '').toLowerCase();
        if (!memberRole.contains(roleFilter!.toLowerCase())) return false;
      }
      // Filtro por estado de inscripción
      if (enrolledFilter != null) {
        if (m.isEnrolled != enrolledFilter) return false;
      }
      return true;
    }).toList();
  }
}

/// Provider para los filtros de miembros (estado mutable)
final memberFiltersProvider =
    StateProvider<MemberFilters>((ref) => const MemberFilters());

/// Provider para los filtros de solicitudes de ingreso
class JoinRequestFilters {
  final String searchQuery;
  final JoinRequestStatus? statusFilter;

  const JoinRequestFilters({
    this.searchQuery = '',
    this.statusFilter,
  });

  JoinRequestFilters copyWith({
    String? searchQuery,
    JoinRequestStatus? statusFilter,
    bool clearStatus = false,
  }) {
    return JoinRequestFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatus ? null : (statusFilter ?? this.statusFilter),
    );
  }

  List<JoinRequest> applyTo(List<JoinRequest> requests) {
    return requests.where((r) {
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!r.fullName.toLowerCase().contains(query)) return false;
      }
      if (statusFilter != null && r.status != statusFilter) return false;
      return true;
    }).toList();
  }
}

final joinRequestFiltersProvider =
    StateProvider<JoinRequestFilters>((ref) => const JoinRequestFilters());

// ── Members notifier ──────────────────────────────────────────────────────────

/// Estado del notifier de miembros
class MiembrosState {
  final List<ClubMember> members;
  final List<JoinRequest> joinRequests;
  final bool isLoading;
  final bool isLoadingRequests;
  final String? error;
  final String? requestsError;

  const MiembrosState({
    this.members = const [],
    this.joinRequests = const [],
    this.isLoading = false,
    this.isLoadingRequests = false,
    this.error,
    this.requestsError,
  });

  MiembrosState copyWith({
    List<ClubMember>? members,
    List<JoinRequest>? joinRequests,
    bool? isLoading,
    bool? isLoadingRequests,
    String? error,
    bool clearError = false,
    String? requestsError,
    bool clearRequestsError = false,
  }) {
    return MiembrosState(
      members: members ?? this.members,
      joinRequests: joinRequests ?? this.joinRequests,
      isLoading: isLoading ?? this.isLoading,
      isLoadingRequests: isLoadingRequests ?? this.isLoadingRequests,
      error: clearError ? null : (error ?? this.error),
      requestsError:
          clearRequestsError ? null : (requestsError ?? this.requestsError),
    );
  }

  /// Número de solicitudes pendientes
  int get pendingRequestsCount =>
      joinRequests.where((r) => r.status == JoinRequestStatus.pending).length;
}

/// Notifier principal para el módulo de miembros
class MiembrosNotifier extends Notifier<MiembrosState> {
  @override
  MiembrosState build() {
    // Cuando el contexto del club cambie, cargar automáticamente
    ref.listen<AsyncValue<ClubContext?>>(clubContextProvider, (_, next) {
      next.whenData((ctx) {
        if (ctx != null) {
          loadMembers(ctx);
          loadJoinRequests(ctx);
        }
      });
    });
    return const MiembrosState();
  }

  /// Carga los miembros del club
  Future<void> loadMembers(ClubContext context) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await ref.read(getClubMembersUseCaseProvider)(
      GetClubMembersParams(
        clubId: context.clubId,
        instanceType: context.instanceType,
        instanceId: context.instanceId,
      ),
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
      (members) => state = state.copyWith(
        isLoading: false,
        members: members,
        clearError: true,
      ),
    );
  }

  /// Carga las solicitudes de ingreso
  Future<void> loadJoinRequests(ClubContext context) async {
    state = state.copyWith(isLoadingRequests: true, clearRequestsError: true);

    final result = await ref.read(getJoinRequestsUseCaseProvider)(
      GetJoinRequestsParams(
        clubId: context.clubId,
        instanceType: context.instanceType,
        instanceId: context.instanceId,
      ),
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoadingRequests: false,
        requestsError: failure.message,
      ),
      (requests) => state = state.copyWith(
        isLoadingRequests: false,
        joinRequests: requests,
        clearRequestsError: true,
      ),
    );
  }

  /// Asigna un rol de club a un miembro
  Future<bool> assignRole({
    required ClubContext context,
    required String userId,
    required String role,
  }) async {
    final result = await ref.read(assignClubRoleUseCaseProvider)(
      AssignClubRoleParams(
        clubId: context.clubId,
        instanceType: context.instanceType,
        instanceId: context.instanceId,
        userId: userId,
        role: role,
      ),
    );

    return result.fold(
      (failure) => false,
      (success) {
        // Refrescar la lista de miembros tras la asignación
        loadMembers(context);
        return success;
      },
    );
  }

  /// Aprueba una solicitud de ingreso
  Future<bool> approveRequest(int requestId, ClubContext context) async {
    final repo = ref.read(miembrosRepositoryProvider);
    final result = await repo.approveJoinRequest(requestId);
    return result.fold(
      (failure) => false,
      (_) {
        loadJoinRequests(context);
        return true;
      },
    );
  }

  /// Rechaza una solicitud de ingreso
  Future<bool> rejectRequest(int requestId, ClubContext context) async {
    final repo = ref.read(miembrosRepositoryProvider);
    final result = await repo.rejectJoinRequest(requestId);
    return result.fold(
      (failure) => false,
      (_) {
        loadJoinRequests(context);
        return true;
      },
    );
  }

  /// Refresca todos los datos
  Future<void> refresh(ClubContext context) async {
    await Future.wait([
      loadMembers(context),
      loadJoinRequests(context),
    ]);
  }
}

/// Provider del notifier de miembros
final miembrosNotifierProvider =
    NotifierProvider<MiembrosNotifier, MiembrosState>(() {
  return MiembrosNotifier();
});

// ── Derived / computed providers ──────────────────────────────────────────────

/// Miembros filtrados según los filtros activos
final filteredMembersProvider = Provider<List<ClubMember>>((ref) {
  final members = ref.watch(miembrosNotifierProvider).members;
  final filters = ref.watch(memberFiltersProvider);
  return filters.applyTo(members);
});

/// Solicitudes filtradas según los filtros activos
final filteredJoinRequestsProvider = Provider<List<JoinRequest>>((ref) {
  final requests = ref.watch(miembrosNotifierProvider).joinRequests;
  final filters = ref.watch(joinRequestFiltersProvider);
  return filters.applyTo(requests);
});

/// Número de solicitudes pendientes (para el badge del tab)
final pendingRequestsCountProvider = Provider<int>((ref) {
  return ref.watch(miembrosNotifierProvider).pendingRequestsCount;
});

/// Clases únicas presentes en la lista de miembros (para el filtro)
final availableClassesProvider = Provider<List<String>>((ref) {
  final members = ref.watch(miembrosNotifierProvider).members;
  final classes = members
      .map((m) => m.currentClass)
      .whereType<String>()
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return classes;
});

/// Roles únicos presentes en la lista de miembros (para el filtro)
final availableRolesProvider = Provider<List<String>>((ref) {
  final members = ref.watch(miembrosNotifierProvider).members;
  final roles = members
      .map((m) => m.clubRole)
      .whereType<String>()
      .where((r) => r.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return roles;
});

/// Miembros agrupados por clase progresiva
final membersByClassProvider =
    Provider<Map<String, List<ClubMember>>>((ref) {
  final members = ref.watch(filteredMembersProvider);
  final grouped = <String, List<ClubMember>>{};

  for (final member in members) {
    final key = member.currentClass ?? 'Sin clase';
    grouped.putIfAbsent(key, () => []).add(member);
  }

  // Ordenar los grupos por nombre de clase
  final ordered = <String, List<ClubMember>>{};
  final sortedKeys = grouped.keys.toList()..sort((a, b) {
    // "Sin clase" siempre al final
    if (a == 'Sin clase') return 1;
    if (b == 'Sin clase') return -1;
    return _classOrder(a).compareTo(_classOrder(b));
  });
  for (final key in sortedKeys) {
    ordered[key] = grouped[key]!;
  }
  return ordered;
});

/// Orden de las clases de Conquistadores para presentación
int _classOrder(String className) {
  const order = {
    'Amigo': 1,
    'Compañero': 2,
    'Explorador': 3,
    'Viajero': 4,
    'Guía': 5,
    'Pionero': 6,
    'Pathfinder': 7,
  };
  return order[className] ?? 99;
}
