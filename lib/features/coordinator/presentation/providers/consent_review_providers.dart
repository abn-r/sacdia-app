import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/consent_pending_queue.dart';
import 'coordinator_providers.dart';

/// 403 del servidor: no hay ninguna asignación de coordinador vigente (no tiene
/// secciones asignadas).
const String _scopeRequiredCode = 'GUARD_CLUB_SCOPE_REQUIRED';

/// 403 del servidor: la persona no es coordinadora con `consent:verify`, o
/// actúa como tutor / menor / dispositivo.
const Set<String> _deniedCodes = {
  'GUARD_PERMISSION_DENIED',
  'ACTING_FOR_SCOPE_DENIED',
  'PRINCIPAL_SCOPE_DENIED',
};

/// Si la persona puede ver la cola de fichas por verificar.
enum ConsentQueueAccess {
  /// Hay cola (puede estar vacía).
  granted,

  /// `GUARD_CLUB_SCOPE_REQUIRED`: sin secciones asignadas.
  noSections,

  /// `GUARD_PERMISSION_DENIED` y similares: la cola no es para esta persona.
  denied,
}

/// Estado de la cola "Fichas por verificar" del coordinador.
class ConsentReviewState extends Equatable {
  final ConsentQueueAccess access;

  /// Las fichas cargadas hasta ahora, de la más antigua a la más nueva.
  final List<ConsentPendingItem> items;

  /// Fichas por verificar en toda la cola (no solo las cargadas).
  final int total;

  /// Cuántas fichas esperan en cada sección.
  final List<ConsentPendingSection> bySection;

  final bool loadingMore;

  /// La última página pedida falló: lo cargado se conserva y se puede reintentar.
  final bool loadMoreFailed;

  const ConsentReviewState({
    this.access = ConsentQueueAccess.granted,
    this.items = const [],
    this.total = 0,
    this.bySection = const [],
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  bool get hasMore =>
      access == ConsentQueueAccess.granted && items.length < total;

  ConsentReviewState copyWith({
    List<ConsentPendingItem>? items,
    int? total,
    List<ConsentPendingSection>? bySection,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) =>
      ConsentReviewState(
        access: access,
        items: items ?? this.items,
        total: total ?? this.total,
        bySection: bySection ?? this.bySection,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );

  @override
  List<Object?> get props =>
      [access, items, total, bySection, loadingMore, loadMoreFailed];
}

/// Cola de fichas de consentimiento por verificar en TODAS las secciones que
/// cubre el coordinador (`consent:verify`).
///
/// Una sola llamada a `GET /coordination/me/consent-pending` por página: el
/// servidor ya resuelve el alcance, filtra lo que hay que verificar y ordena de
/// la ficha más antigua a la más nueva. Las páginas siguientes se piden con
/// `offset` = lo ya listado (una ficha verificada sale de la cola del servidor
/// igual que de la lista, así que el desplazamiento sigue cuadrando).
class ConsentReviewNotifier
    extends AutoDisposeAsyncNotifier<ConsentReviewState> {
  /// Fichas por página: el valor por defecto del endpoint.
  static const int pageSize = 50;

  /// Token de la carga vigente. El notifier SOBREVIVE a `ref.invalidate`
  /// (Riverpod 2.6 solo vuelve a correr `build`), así que cada `build` crea el
  /// suyo y cancela únicamente ese al descartarse: reutilizar uno ya cancelado
  /// haría fallar toda recarga.
  CancelToken _cancelToken = CancelToken();

  /// Cuántas veces corrió `build`. Una respuesta que llega de una generación
  /// anterior (o ya cancelada) se descarta.
  int _generation = 0;

  /// Lo verificado en esta generación, para que una página que ya venía en
  /// camino no resucite esas filas.
  final Set<String> _removedAssignmentIds = {};
  final Set<String> _removedUserIds = {};

  @override
  Future<ConsentReviewState> build() async {
    final token = CancelToken();
    _cancelToken = token;
    _generation++;
    _removedAssignmentIds.clear();
    _removedUserIds.clear();
    ref.onDispose(token.cancel);

    final result =
        await ref.read(coordinatorRepositoryProvider).getConsentPending(
              limit: pageSize,
              offset: 0,
              cancelToken: token,
            );
    return result.fold(
      (failure) => switch (_accessOf(failure)) {
        final access? => ConsentReviewState(access: access),
        null => throw failure,
      },
      (page) => ConsentReviewState(
        items: page.items,
        total: page.total,
        bySection: page.bySection,
      ),
    );
  }

  /// Decide por el código de negocio, nunca por el mensaje. `null` = un error
  /// cualquiera (red, 5xx), que se reintenta.
  static ConsentQueueAccess? _accessOf(Failure failure) {
    final code = failure.errorCode;
    if (code == _scopeRequiredCode) return ConsentQueueAccess.noSections;
    if (code != null && _deniedCodes.contains(code)) {
      return ConsentQueueAccess.denied;
    }
    return null;
  }

  /// Pide la página siguiente y la agrega al final. Con la lista vacía y fichas
  /// por traer (todas las cargadas se verificaron), vuelve a pedir desde el
  /// principio.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;
    final token = _cancelToken;
    state = AsyncData(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );

    final result =
        await ref.read(coordinatorRepositoryProvider).getConsentPending(
              limit: pageSize,
              offset: current.items.length,
              cancelToken: token,
            );
    if (generation != _generation || token.isCancelled) return;

    // Se parte del estado VIGENTE, no del de antes del await: mientras tanto
    // pudo verificarse una ficha ([removeRequest]).
    final latest = state.valueOrNull;
    if (latest == null) return;

    state = AsyncData(
      result.fold(
        (_) => latest.copyWith(loadingMore: false, loadMoreFailed: true),
        (page) {
          final known = {for (final item in latest.items) item.assignmentId};
          final fresh = [
            for (final item in page.items)
              if (!known.contains(item.assignmentId) &&
                  !_removedAssignmentIds.contains(item.assignmentId) &&
                  !_removedUserIds.contains(item.request.userId))
                item,
          ];
          final items = [...latest.items, ...fresh];
          return latest.copyWith(
            items: items,
            // El servidor manda: su total y sus conteos son los vigentes. Una
            // página sin nada que traer cierra la lista aunque el total diga
            // otra cosa (si no, "Cargar más" quedaría pidiendo lo mismo).
            total: page.items.isEmpty && page.total > items.length
                ? items.length
                : page.total,
            bySection: page.bySection,
            loadingMore: false,
            loadMoreFailed: false,
          );
        },
      ),
    );
  }

  /// Quita una ficha ya verificada: baja el total y el conteo de su sección (que
  /// sale del resumen al llegar a cero).
  ///
  /// Verificar una ficha limpia en el servidor TODAS las pendientes del mismo
  /// menor (la verificación es por usuario), así que salen todas las filas de
  /// ese `userId`, cada una con su sección.
  void removeRequest(String assignmentId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final target = current.items
        .where((item) => item.assignmentId == assignmentId)
        .firstOrNull;
    if (target == null) return;

    final userId = target.request.userId;
    final removed = [
      for (final item in current.items)
        if (item.request.userId == userId) item,
    ];
    _removedUserIds.add(userId);
    _removedAssignmentIds.addAll(removed.map((item) => item.assignmentId));

    final perSection = <int?, int>{};
    for (final item in removed) {
      perSection.update(item.clubSectionId, (n) => n + 1, ifAbsent: () => 1);
    }
    final bySection = <ConsentPendingSection>[
      for (final section in current.bySection)
        if (section.pendingConsentCount -
                (perSection[section.clubSectionId] ?? 0) >
            0)
          section.copyWith(
            pendingConsentCount: section.pendingConsentCount -
                (perSection[section.clubSectionId] ?? 0),
          ),
    ];
    final total = current.total - removed.length;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            if (item.request.userId != userId) item,
        ],
        total: total > 0 ? total : 0,
        bySection: bySection,
      ),
    );
  }
}

/// Cola de fichas por verificar del coordinador.
final consentReviewProvider = AsyncNotifierProvider.autoDispose<
    ConsentReviewNotifier, ConsentReviewState>(ConsentReviewNotifier.new);

/// Cuántas fichas esperan verificación (para el badge del hub): una página de
/// UNA ficha, solo para leer el total. `null` si no se pudo saber: sin badge.
final consentPendingCountProvider =
    FutureProvider.autoDispose<int?>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  final result =
      await ref.read(coordinatorRepositoryProvider).getConsentPending(
            limit: 1,
            offset: 0,
            cancelToken: cancelToken,
          );
  return result.fold((_) => null, (page) => page.total);
});
