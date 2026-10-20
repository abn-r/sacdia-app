import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../members/domain/entities/join_request.dart';
import '../../../members/domain/usecases/get_join_requests.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/coordinator_scope.dart';
import 'coordinator_providers.dart';

/// 403 del servidor: la sección ya no está en el alcance del coordinador
/// (asignación vencida o cambiada desde que se cargó el alcance).
const String _scopeRequiredCode = 'GUARD_CLUB_SCOPE_REQUIRED';

/// Una sección del alcance con las fichas que esperan verificación.
class ConsentReviewSection {
  final CoordinatorSectionScope section;
  final List<JoinRequest> requests;

  const ConsentReviewSection({required this.section, required this.requests});

  ConsentReviewSection copyWith({List<JoinRequest>? requests}) =>
      ConsentReviewSection(
        section: section,
        requests: requests ?? this.requests,
      );
}

/// Estado de la cola "Fichas por verificar" del coordinador.
class ConsentReviewState {
  /// Todas las secciones del alcance, en el orden del servidor.
  final List<CoordinatorSectionScope> sections;

  /// Cuántas secciones (de [sections], en orden) ya se consultaron.
  final int checkedCount;

  /// Solo las secciones con al menos una ficha por verificar, en el orden de
  /// [sections].
  final List<ConsentReviewSection> entries;

  /// Consulta fallida (red, 5xx): se puede reintentar.
  final Set<int> failedSectionIds;

  /// 403 `GUARD_CLUB_SCOPE_REQUIRED`: ya no está en el alcance. No se reintenta.
  final Set<int> droppedSectionIds;

  final bool loadingMore;

  const ConsentReviewState({
    this.sections = const [],
    this.checkedCount = 0,
    this.entries = const [],
    this.failedSectionIds = const {},
    this.droppedSectionIds = const {},
    this.loadingMore = false,
  });

  bool get hasMore => checkedCount < sections.length;

  int get totalForms =>
      entries.fold(0, (total, entry) => total + entry.requests.length);

  ConsentReviewState copyWith({
    int? checkedCount,
    List<ConsentReviewSection>? entries,
    Set<int>? failedSectionIds,
    Set<int>? droppedSectionIds,
    bool? loadingMore,
  }) =>
      ConsentReviewState(
        sections: sections,
        checkedCount: checkedCount ?? this.checkedCount,
        entries: entries ?? this.entries,
        failedSectionIds: failedSectionIds ?? this.failedSectionIds,
        droppedSectionIds: droppedSectionIds ?? this.droppedSectionIds,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Cola de fichas de consentimiento por verificar en el alcance del
/// coordinador (`consent:verify`).
///
/// **Cómo se acota la carga.** El alcance puede cubrir cientos de secciones
/// (una asignación GENERAL abarca todo un campo local) y el servidor solo
/// ofrece `GET /club-sections/:id/membership-requests` por sección, sin un
/// listado agregado. Pedir todas a la vez sería una avalancha, así que se pagina
/// POR SECCIÓN: se consultan [sectionsPerPage] secciones a la vez (como mucho
/// ese número de peticiones en vuelo) y las siguientes solo cuando la persona
/// toca "Revisar más secciones". Las secciones sin fichas no se muestran. El
/// servidor ya filtra la lista para quien solo verifica (menores con la ficha
/// por verificar), así que el cliente solo descarta lo que no esté pendiente.
class ConsentReviewNotifier
    extends AutoDisposeAsyncNotifier<ConsentReviewState> {
  /// Secciones consultadas por página. También es el tope de peticiones
  /// simultáneas.
  static const int sectionsPerPage = 5;

  final CancelToken _cancelToken = CancelToken();
  bool _disposed = false;

  @override
  Future<ConsentReviewState> build() async {
    ref.onDispose(() {
      _disposed = true;
      _cancelToken.cancel();
    });

    final scope = await ref.watch(coordinatorScopeProvider.future);
    final initial = ConsentReviewState(sections: _sectionsOf(scope));
    return _loadNextPage(initial);
  }

  /// Secciones del alcance. Sin el detalle (`sections`), se cae a los ids.
  static List<CoordinatorSectionScope> _sectionsOf(CoordinatorScope scope) {
    if (!scope.isCoordinator) return const [];
    if (scope.sections.isNotEmpty) return scope.sections;
    return [
      for (final id in scope.clubSectionIds)
        CoordinatorSectionScope(clubSectionId: id, clubTypeId: 0),
    ];
  }

  /// Consulta la siguiente página de secciones.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    final next = await _loadNextPage(current);
    if (_disposed) return;
    state = AsyncData(next.copyWith(loadingMore: false));
  }

  /// Vuelve a consultar solo las secciones que fallaron (en páginas).
  Future<void> retryFailed() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.failedSectionIds.isEmpty ||
        current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    final retry = [
      for (final section in current.sections)
        if (current.failedSectionIds.contains(section.clubSectionId)) section,
    ];
    var next = current.copyWith(failedSectionIds: const {});
    for (var i = 0; i < retry.length; i += sectionsPerPage) {
      next = await _fetchInto(next, retry.skip(i).take(sectionsPerPage));
      if (_disposed) return;
    }
    state = AsyncData(next.copyWith(loadingMore: false));
  }

  /// Quita una ficha ya verificada (y su sección si se quedó sin fichas).
  void removeRequest(String assignmentId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final entries = <ConsentReviewSection>[];
    for (final entry in current.entries) {
      final requests = [
        for (final r in entry.requests)
          if (r.assignmentId != assignmentId) r,
      ];
      if (requests.isNotEmpty) entries.add(entry.copyWith(requests: requests));
    }
    state = AsyncData(current.copyWith(entries: entries));
  }

  Future<ConsentReviewState> _loadNextPage(ConsentReviewState current) async {
    final page = current.sections
        .skip(current.checkedCount)
        .take(sectionsPerPage)
        .toList();
    if (page.isEmpty) return current;
    final loaded = await _fetchInto(current, page);
    return loaded.copyWith(checkedCount: current.checkedCount + page.length);
  }

  /// Pide [page] en paralelo (nunca más de [sectionsPerPage]) y mezcla el
  /// resultado en [current] respetando el orden de las secciones.
  Future<ConsentReviewState> _fetchInto(
    ConsentReviewState current,
    Iterable<CoordinatorSectionScope> page,
  ) async {
    final sections = page.toList();
    final outcomes = await Future.wait(sections.map(_fetchSection));

    final order = {
      for (var i = 0; i < current.sections.length; i++)
        current.sections[i].clubSectionId: i,
    };
    final entries = [...current.entries];
    final failed = {...current.failedSectionIds};
    final dropped = {...current.droppedSectionIds};

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final outcome = outcomes[i];
      switch (outcome) {
        case _Dropped():
          dropped.add(section.clubSectionId);
        case _Failed():
          failed.add(section.clubSectionId);
        case _Loaded(:final requests):
          entries.removeWhere(
            (e) => e.section.clubSectionId == section.clubSectionId,
          );
          if (requests.isNotEmpty) {
            entries.add(
              ConsentReviewSection(section: section, requests: requests),
            );
          }
      }
    }
    entries.sort(
      (a, b) => (order[a.section.clubSectionId] ?? 0)
          .compareTo(order[b.section.clubSectionId] ?? 0),
    );

    return ConsentReviewState(
      sections: current.sections,
      checkedCount: current.checkedCount,
      entries: entries,
      failedSectionIds: failed,
      droppedSectionIds: dropped,
      loadingMore: current.loadingMore,
    );
  }

  Future<_SectionOutcome> _fetchSection(CoordinatorSectionScope section) async {
    try {
      final result = await ref.read(getJoinRequestsUseCaseProvider)(
        GetJoinRequestsParams(
          clubId: section.clubId ?? 0,
          sectionId: section.clubSectionId,
        ),
        cancelToken: _cancelToken,
      );
      return result.fold(
        (failure) => failure.errorCode == _scopeRequiredCode
            ? const _Dropped()
            : const _Failed(),
        (requests) => _Loaded([
          for (final request in requests)
            if (request.consentPending) request,
        ]),
      );
    } catch (_) {
      return const _Failed();
    }
  }
}

sealed class _SectionOutcome {
  const _SectionOutcome();
}

class _Loaded extends _SectionOutcome {
  const _Loaded(this.requests);
  final List<JoinRequest> requests;
}

class _Dropped extends _SectionOutcome {
  const _Dropped();
}

class _Failed extends _SectionOutcome {
  const _Failed();
}

/// Cola de fichas por verificar del coordinador.
final consentReviewProvider = AsyncNotifierProvider.autoDispose<
    ConsentReviewNotifier, ConsentReviewState>(ConsentReviewNotifier.new);
