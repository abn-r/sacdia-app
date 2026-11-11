import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/keep_alive_during.dart';
import '../../domain/entities/role_candidate.dart';
import 'members_providers.dart';

/// Qué se pide a `GET .../role-candidates`: la sección que recibe el cargo, el
/// filtro y la búsqueda. Cambiar cualquiera crea otro provider (otra lista).
class RoleCandidatesQuery extends Equatable {
  const RoleCandidatesQuery({
    required this.clubId,
    required this.sectionId,
    this.filter = RoleCandidatesFilter.available,
    this.search = '',
  });

  final int clubId;
  final int sectionId;
  final RoleCandidatesFilter filter;
  final String search;

  @override
  List<Object?> get props => [clubId, sectionId, filter, search];
}

/// Lo cargado hasta ahora de una consulta: las páginas ya recibidas más los
/// metadatos (cupos, conteos) de la primera.
class RoleCandidatesState extends Equatable {
  const RoleCandidatesState({
    required this.first,
    required this.items,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  /// Primera página: `section`, `slots`, `counts` y `total` salen de aquí.
  final RoleCandidatesPage first;
  final List<RoleCandidate> items;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  RoleCandidatesSection? get section => first.section;
  List<RoleSlot> get slots => first.slots;
  RoleCandidatesCounts get counts => first.counts;
  int get total => first.total;
  bool get hasMore => items.length < total;

  RoleCandidatesState copyWith({
    List<RoleCandidate>? items,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) =>
      RoleCandidatesState(
        first: first,
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );

  @override
  List<Object?> get props => [first, items, isLoadingMore, loadMoreFailed];
}

/// Lista paginada de candidatos. `autoDispose`: nada de esto debe sobrevivir a
/// la hoja ni a un cambio de perfil. Falla con el [Failure] original.
class RoleCandidatesNotifier extends AsyncNotifier<RoleCandidatesState> {
  RoleCandidatesNotifier(this.query);

  final RoleCandidatesQuery query;

  @override
  Future<RoleCandidatesState> build() async {
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);
    final result = await ref.read(membersRepositoryProvider).getRoleCandidates(
          clubId: query.clubId,
          sectionId: query.sectionId,
          search: query.search,
          filter: query.filter,
          cancelToken: cancelToken,
        );
    return result.fold(
      (failure) => throw failure,
      (page) => RoleCandidatesState(first: page, items: page.items),
    );
  }

  /// Pide la página siguiente. Un fallo no tira la lista: deja
  /// [RoleCandidatesState.loadMoreFailed] para ofrecer reintento.
  Future<void> loadMore() => ref.keepAliveDuring(() async {
        final current = state.value;
        if (current == null || current.isLoadingMore || !current.hasMore) {
          return;
        }
        state = AsyncData(
          current.copyWith(isLoadingMore: true, loadMoreFailed: false),
        );
        final nextPage = current.items.isEmpty
            ? 1
            : (current.items.length ~/ current.first.limit) + 1;
        final result =
            await ref.read(membersRepositoryProvider).getRoleCandidates(
                  clubId: query.clubId,
                  sectionId: query.sectionId,
                  search: query.search,
                  filter: query.filter,
                  page: nextPage,
                  limit: current.first.limit,
                );
        if (!ref.mounted) return;
        state = AsyncData(
          result.fold(
            (_) => current.copyWith(isLoadingMore: false, loadMoreFailed: true),
            (page) {
              final known = {for (final i in current.items) i.userId};
              return current.copyWith(
                items: [
                  ...current.items,
                  ...page.items.where((i) => !known.contains(i.userId)),
                ],
                isLoadingMore: false,
              );
            },
          ),
        );
      });
}

final roleCandidatesProvider = AsyncNotifierProvider.autoDispose
    .family<RoleCandidatesNotifier, RoleCandidatesState, RoleCandidatesQuery>(
  RoleCandidatesNotifier.new,
);

class RoleCandidateDetailQuery extends Equatable {
  const RoleCandidateDetailQuery({
    required this.clubId,
    required this.sectionId,
    required this.userId,
  });

  final int clubId;
  final int sectionId;
  final String userId;

  @override
  List<Object?> get props => [clubId, sectionId, userId];
}

/// Detalle de un candidato. Falla con el [Failure] original.
final roleCandidateDetailProvider = FutureProvider.autoDispose
    .family<RoleCandidateDetail, RoleCandidateDetailQuery>((ref, query) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result =
      await ref.read(membersRepositoryProvider).getRoleCandidateDetail(
            clubId: query.clubId,
            sectionId: query.sectionId,
            userId: query.userId,
            cancelToken: cancelToken,
          );
  return result.fold((failure) => throw failure, (detail) => detail);
});
