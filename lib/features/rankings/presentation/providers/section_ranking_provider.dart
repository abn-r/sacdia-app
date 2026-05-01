import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/rankings_remote_data_source.dart';
import '../../data/repositories/section_rankings_repository_impl.dart';
import '../../domain/entities/section_ranking.dart';
import '../../domain/repositories/section_rankings_repository.dart';

// ── Param types ───────────────────────────────────────────────────────────────

/// Parameter record for [sectionMembersProvider].
typedef SectionMembersParams = ({int sectionId, int yearId});

// ── Infrastructure provider ───────────────────────────────────────────────────

/// Provider for the section rankings repository.
/// Reads the shared [rankingsRemoteDataSourceProvider] defined in the data layer.
final sectionRankingsRepositoryProvider =
    Provider<SectionRankingsRepository>((ref) {
  return SectionRankingsRepositoryImpl(
    remoteDataSource: ref.read(rankingsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Fetches members ranked within a specific section.
///
/// Director sees real names (RBAC enforced server-side).
final sectionMembersProvider = FutureProvider.autoDispose
    .family<List<SectionMember>, SectionMembersParams>(
        (ref, params) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final repo = ref.watch(sectionRankingsRepositoryProvider);
  final result = await repo.getSectionMembers(
    params.sectionId,
    params.yearId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw failure,
    (members) => members,
  );
});
