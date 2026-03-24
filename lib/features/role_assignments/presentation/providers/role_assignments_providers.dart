import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/role_assignments_remote_data_source.dart';
import '../../data/repositories/role_assignments_repository_impl.dart';
import '../../domain/entities/role_assignment.dart';
import '../../domain/repositories/role_assignments_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final roleAssignmentsRemoteDataSourceProvider =
    Provider<RoleAssignmentsRemoteDataSource>((ref) {
  return RoleAssignmentsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final roleAssignmentsRepositoryProvider =
    Provider<RoleAssignmentsRepository>((ref) {
  return RoleAssignmentsRepositoryImpl(
    remoteDataSource: ref.read(roleAssignmentsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Provider para la lista de asignaciones del usuario.
final roleAssignmentsProvider =
    FutureProvider.autoDispose<List<RoleAssignment>>((ref) async {
  final repo = ref.read(roleAssignmentsRepositoryProvider);
  final result = await repo.getAssignments();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (assignments) => assignments,
  );
});
