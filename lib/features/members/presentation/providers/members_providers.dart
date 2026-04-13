import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classes/data/datasources/classes_remote_data_source.dart';
import '../../../classes/domain/entities/progressive_class.dart';
import '../../../honors/data/datasources/honors_remote_data_source.dart';
import '../../../honors/domain/entities/user_honor.dart';
import '../../../post_registration/data/datasources/personal_info_remote_data_source.dart';
import '../../../post_registration/data/models/allergy_model.dart';
import '../../../post_registration/data/models/disease_model.dart';
import '../../../post_registration/data/models/emergency_contact_model.dart';
import '../../../post_registration/data/models/medicine_model.dart';
import '../../data/datasources/members_remote_data_source.dart';
import '../../data/repositories/members_repository_impl.dart';
import '../../domain/entities/club_member.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/repositories/members_repository.dart';
import '../../domain/usecases/assign_club_role.dart';
import '../../domain/usecases/get_club_members.dart';
import '../../domain/usecases/get_join_requests.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

/// Provider de la fuente de datos remota de miembros
final membersRemoteDataSourceProvider =
    Provider<MembersRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);
  return MembersRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);
});

/// Provider del repositorio de miembros
final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final remoteDataSource = ref.read(membersRemoteDataSourceProvider);
  return MembersRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

// ── Use case providers ────────────────────────────────────────────────────────

final getClubMembersUseCaseProvider = Provider<GetClubMembers>((ref) {
  return GetClubMembers(ref.read(membersRepositoryProvider));
});

final getJoinRequestsUseCaseProvider = Provider<GetJoinRequests>((ref) {
  return GetJoinRequests(ref.read(membersRepositoryProvider));
});

final assignClubRoleUseCaseProvider = Provider<AssignClubRole>((ref) {
  return AssignClubRole(ref.read(membersRepositoryProvider));
});

// ── Context providers — club/section values ──────────────────────────────────

/// Estado del contexto del club activo (clubId, sectionId, roleName, clubTypeName)
class ClubContext {
  final int clubId;
  final int sectionId;

  /// Role name of the active assignment (e.g. 'director', 'counselor').
  /// Null when not available from the authorization grant.
  final String? roleName;

  /// Human-readable club type name (e.g. 'Conquistadores', 'Aventureros').
  /// Populated from the active authorization grant's club_type_name field.
  final String? clubTypeName;

  const ClubContext({
    required this.clubId,
    required this.sectionId,
    this.roleName,
    this.clubTypeName,
  });

  /// Whether the active user is a director in this club context.
  bool get isDirector =>
      roleName?.trim().toLowerCase() == 'director';
}

/// Provider del contexto del club activo.
/// Fuente oficial: `authorization.activeGrant` del UserEntity.
///
/// Usa [selectAsync] para que este provider solo se reconstruya cuando el
/// [activeGrant] cambia efectivamente, evitando re-fetches innecesarios por
/// cambios en otras partes del [UserEntity] (e.g. avatar, nombre).
final clubContextProvider = FutureProvider<ClubContext?>((ref) async {
  final activeGrant = await ref.watch(
    authNotifierProvider.selectAsync((u) => u?.authorization?.activeGrant),
  );

  if (activeGrant == null ||
      activeGrant.clubId == null ||
      activeGrant.sectionId == null) {
    return null;
  }

  return ClubContext(
    clubId: activeGrant.clubId!,
    sectionId: activeGrant.sectionId!,
    roleName: activeGrant.roleName,
    clubTypeName: activeGrant.clubTypeName,
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
    StateProvider.autoDispose<MemberFilters>((ref) => const MemberFilters());

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
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
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
    StateProvider.autoDispose<JoinRequestFilters>((ref) => const JoinRequestFilters());

// ── Members data ──────────────────────────────────────────────────────────────

/// Datos del notifier de miembros (sin estado de loading/error — lo maneja AsyncValue)
class MembersData {
  final List<ClubMember> members;
  final List<JoinRequest> joinRequests;

  const MembersData({
    this.members = const [],
    this.joinRequests = const [],
  });

  /// Número de solicitudes pendientes
  int get pendingRequestsCount =>
      joinRequests.where((r) => r.status == JoinRequestStatus.pending).length;
}

// ── Members notifier ──────────────────────────────────────────────────────────

/// Notifier principal para el módulo de miembros.
/// Usa AutoDisposeAsyncNotifier para que el estado de loading/error sea manejado
/// automáticamente por AsyncValue, eliminando los campos manuales isLoading/error,
/// y para liberar memoria cuando el árbol de widgets que lo consume se desmonta.
class MembersNotifier extends AutoDisposeAsyncNotifier<MembersData> {
  @override
  Future<MembersData> build() async {
    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel());

    // ref.watch sobre clubContextProvider dispara rebuild automático
    // cuando el contexto del club cambia (login, cambio de club, etc.)
    final ctx = await ref.watch(clubContextProvider.future);
    if (ctx == null) return const MembersData();

    final membersResult = await ref.read(getClubMembersUseCaseProvider)(
      GetClubMembersParams(
        clubId: ctx.clubId,
        sectionId: ctx.sectionId,
      ),
      cancelToken: cancelToken,
    );

    final requestsResult = await ref.read(getJoinRequestsUseCaseProvider)(
      GetJoinRequestsParams(
        clubId: ctx.clubId,
        sectionId: ctx.sectionId,
      ),
      cancelToken: cancelToken,
    );

    return MembersData(
      members: membersResult.fold((_) => [], (m) => m),
      joinRequests: requestsResult.fold((_) => [], (r) => r),
    );
  }

  /// Asigna un rol de club a un miembro y recarga los datos
  Future<bool> assignRole({
    required ClubContext context,
    required String userId,
    required String role,
  }) async {
    final result = await ref.read(assignClubRoleUseCaseProvider)(
      AssignClubRoleParams(
        clubId: context.clubId,
        sectionId: context.sectionId,
        userId: userId,
        role: role,
      ),
    );

    return result.fold(
      (_) => false,
      (success) {
        if (success) ref.invalidateSelf();
        return success;
      },
    );
  }

  /// Aprueba una solicitud de ingreso y recarga los datos
  Future<bool> approveRequest(String assignmentId) async {
    final repo = ref.read(membersRepositoryProvider);
    final result = await repo.approveJoinRequest(assignmentId);
    return result.fold(
      (_) => false,
      (_) {
        ref.invalidateSelf();
        return true;
      },
    );
  }

  /// Rechaza una solicitud de ingreso y recarga los datos
  Future<bool> rejectRequest(String assignmentId) async {
    final repo = ref.read(membersRepositoryProvider);
    final result = await repo.rejectJoinRequest(assignmentId);
    return result.fold(
      (_) => false,
      (_) {
        ref.invalidateSelf();
        return true;
      },
    );
  }

  /// Refresca todos los datos invalidando el notifier
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Provider del notifier de miembros
final membersNotifierProvider =
    AsyncNotifierProvider.autoDispose<MembersNotifier, MembersData>(
  MembersNotifier.new,
);

// ── Derived / computed providers ──────────────────────────────────────────────

/// Miembros filtrados según los filtros activos
final filteredMembersProvider = Provider.autoDispose<List<ClubMember>>((ref) {
  final data = ref.watch(membersNotifierProvider).valueOrNull;
  final members = data?.members ?? [];
  final filters = ref.watch(memberFiltersProvider);
  return filters.applyTo(members);
});

/// Solicitudes filtradas según los filtros activos
final filteredJoinRequestsProvider = Provider.autoDispose<List<JoinRequest>>((ref) {
  final data = ref.watch(membersNotifierProvider).valueOrNull;
  final requests = data?.joinRequests ?? [];
  final filters = ref.watch(joinRequestFiltersProvider);
  return filters.applyTo(requests);
});

/// Número de solicitudes pendientes (para el badge del tab)
final pendingRequestsCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(membersNotifierProvider).valueOrNull?.pendingRequestsCount ??
      0;
});

/// Clases únicas presentes en la lista de miembros (para el filtro)
final availableClassesProvider = Provider.autoDispose<List<String>>((ref) {
  final members =
      ref.watch(membersNotifierProvider).valueOrNull?.members ?? [];
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
final availableRolesProvider = Provider.autoDispose<List<String>>((ref) {
  final members =
      ref.watch(membersNotifierProvider).valueOrNull?.members ?? [];
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
final membersByClassProvider = Provider.autoDispose<Map<String, List<ClubMember>>>((ref) {
  final members = ref.watch(filteredMembersProvider);
  final grouped = <String, List<ClubMember>>{};

  for (final member in members) {
    final key = member.currentClass ?? 'Sin clase';
    grouped.putIfAbsent(key, () => []).add(member);
  }

  // Ordenar los grupos por nombre de clase
  final ordered = <String, List<ClubMember>>{};
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) {
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

// ── Member detail provider ─────────────────────────────────────────────────────

/// Obtiene el detalle completo de un miembro por su userId.
/// Keyed por userId — se cachea de forma independiente por cada miembro visitado.
final memberDetailProvider =
    FutureProvider.autoDispose.family<ClubMember, String>((ref, userId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final repo = ref.read(membersRepositoryProvider);
  final result = await repo.getMemberDetail(userId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (member) => member,
  );
});

// ── Medical data providers scoped to a specific userId ────────────────────────

/// Provider del data source de información personal reutilizable fuera del módulo
/// de post-registro (no expone autoDispose para poder ser usado en family providers).
final _personalInfoDsProvider = Provider<PersonalInfoRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);
  return PersonalInfoRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);
});

/// Alergias de un usuario específico (solo lectura, para vista de perfil de miembro).
final memberAllergiesProvider =
    FutureProvider.autoDispose.family<List<AllergyModel>, String>(
        (ref, userId) async {
  final ds = ref.read(_personalInfoDsProvider);
  return ds.getUserAllergies(userId);
});

/// Enfermedades de un usuario específico (solo lectura, para vista de perfil de miembro).
final memberDiseasesProvider =
    FutureProvider.autoDispose.family<List<DiseaseModel>, String>(
        (ref, userId) async {
  final ds = ref.read(_personalInfoDsProvider);
  return ds.getUserDiseases(userId);
});

/// Medicamentos de un usuario específico (solo lectura, para vista de perfil de miembro).
final memberMedicinesProvider =
    FutureProvider.autoDispose.family<List<MedicineModel>, String>(
        (ref, userId) async {
  final ds = ref.read(_personalInfoDsProvider);
  return ds.getUserMedicines(userId);
});

/// Contactos de emergencia de un usuario específico (solo lectura, para vista de perfil de miembro).
final memberEmergencyContactsProvider =
    FutureProvider.autoDispose.family<List<EmergencyContactModel>, String>(
        (ref, userId) async {
  final ds = ref.read(_personalInfoDsProvider);
  return ds.getEmergencyContacts(userId);
});

// ── Classes and honors data providers for member profile ─────────────────────

/// Data source de clases reutilizable desde el módulo de miembros.
final _classesDsForMembersProvider = Provider<ClassesRemoteDataSource>((ref) {
  return ClassesRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Data source de especialidades reutilizable desde el módulo de miembros.
final _honorsDsForMembersProvider = Provider<HonorsRemoteDataSource>((ref) {
  return HonorsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Clases progresivas de un usuario específico (solo lectura, para vista de perfil de miembro).
final memberClassesProvider =
    FutureProvider.autoDispose.family<List<ProgressiveClass>, String>(
        (ref, userId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final ds = ref.read(_classesDsForMembersProvider);
  final models = await ds.getUserClasses(userId, cancelToken: cancelToken);
  return models.map((m) => m.toEntity()).toList();
});

/// Especialidades de un usuario específico (solo lectura, para vista de perfil de miembro).
final memberHonorsProvider =
    FutureProvider.autoDispose.family<List<UserHonor>, String>(
        (ref, userId) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final ds = ref.read(_honorsDsForMembersProvider);
  final models = await ds.getUserHonors(userId, cancelToken: cancelToken);
  return models.map((m) => m.toEntity()).toList();
});
