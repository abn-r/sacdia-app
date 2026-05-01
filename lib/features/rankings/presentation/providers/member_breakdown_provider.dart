import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/member_breakdown.dart';
import 'my_ranking_provider.dart';

/// Parameter record for [memberBreakdownProvider].
/// Using a Dart record ensures structural equality for provider family keying.
typedef MemberBreakdownParams = ({int enrollmentId, int yearId});

/// Fetches the per-component score breakdown for a specific enrollment.
///
/// Returns:
/// - [AsyncValue.data(MemberBreakdown)] — breakdown available
/// - [AsyncValue.error(Failure)] — auth or network error
///
/// Keyed by [MemberBreakdownParams] so the provider family deduplicates
/// simultaneous requests for the same (enrollmentId, yearId) pair.
final memberBreakdownProvider = FutureProvider.autoDispose
    .family<MemberBreakdown, MemberBreakdownParams>(
        (ref, params) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final repo = ref.watch(memberRankingsRepositoryProvider);
  final result = await repo.getBreakdown(
    params.enrollmentId,
    params.yearId,
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw failure,
    (breakdown) => breakdown,
  );
});
