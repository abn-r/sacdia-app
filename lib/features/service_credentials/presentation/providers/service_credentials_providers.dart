import 'package:dartz/dartz.dart' show Either, Unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../members/presentation/providers/role_candidates_providers.dart';
import '../../data/datasources/service_credentials_remote_data_source.dart';
import '../../data/repositories/service_credentials_repository_impl.dart';
import '../../domain/entities/service_credential.dart';
import '../../domain/entities/service_credential_review.dart';
import '../../domain/repositories/service_credentials_repository.dart';

// ── Infraestructura ──────────────────────────────────────────────────────────

final serviceCredentialsRemoteDataSourceProvider =
    Provider<ServiceCredentialsRemoteDataSource>((ref) {
  return ServiceCredentialsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final serviceCredentialsRepositoryProvider =
    Provider<ServiceCredentialsRepository>((ref) {
  return ServiceCredentialsRepositoryImpl(
    remoteDataSource: ref.read(serviceCredentialsRemoteDataSourceProvider),
  );
});

// ── Mis constancias ──────────────────────────────────────────────────────────

/// Constancias propias, de la más nueva a la más antigua. Falla con el
/// [Failure] original. `autoDispose`: nada de esto sobrevive a la pantalla.
final myServiceCredentialsProvider =
    FutureProvider.autoDispose<List<ServiceCredential>>((ref) async {
  final result = await ref.read(serviceCredentialsRepositoryProvider).getMine();
  return result.fold((failure) => throw failure, (items) {
    // Abandoned uploads (PENDING_UPLOAD, no file) are not a credential the
    // person can act on: hide them. The next registration retires them.
    final sorted = [
      for (final i in items)
        if (i.uploadStatus != ServiceCredentialUploadStatus.pendingUpload) i,
    ];
    sorted.sort((a, b) {
      final left = a.createdAt;
      final right = b.createdAt;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return sorted;
  });
});

/// Avance de una subida en curso.
class ServiceCredentialSubmitState extends Equatable {
  const ServiceCredentialSubmitState({
    this.isBusy = false,
    this.phase,
    this.progress = 0,
  });

  final bool isBusy;
  final ServiceCredentialSubmitPhase? phase;

  /// 0..1 de los bytes enviados a la URL firmada.
  final double progress;

  @override
  List<Object?> get props => [isBusy, phase, progress];
}

/// Registra, sube y confirma una constancia propia.
class ServiceCredentialSubmitNotifier
    extends Notifier<ServiceCredentialSubmitState> {
  @override
  ServiceCredentialSubmitState build() => const ServiceCredentialSubmitState();

  /// `null` si salió bien; el [Failure] si no (con su `errorCode`).
  Future<Failure?> submit({
    required ServiceCredentialDraft draft,
    required ConsentEvidenceLocalFile file,
  }) =>
      ref.keepAliveDuring(() async {
        if (state.isBusy) return null;
        state = const ServiceCredentialSubmitState(
          isBusy: true,
          phase: ServiceCredentialSubmitPhase.registering,
        );
        final result =
            await ref.read(serviceCredentialsRepositoryProvider).submit(
                  draft: draft,
                  file: file,
                  onPhase: (phase) {
                    if (!ref.mounted) return;
                    state = ServiceCredentialSubmitState(
                      isBusy: true,
                      phase: phase,
                      progress: state.progress,
                    );
                  },
                  onProgress: (progress) {
                    if (!ref.mounted) return;
                    state = ServiceCredentialSubmitState(
                      isBusy: true,
                      phase: ServiceCredentialSubmitPhase.uploading,
                      progress: progress,
                    );
                  },
                );
        if (!ref.mounted) return null;
        state = const ServiceCredentialSubmitState();
        return result.fold((failure) => failure, (_) {
          ref.invalidate(myServiceCredentialsProvider);
          return null;
        });
      });
}

final serviceCredentialSubmitProvider = NotifierProvider.autoDispose<
    ServiceCredentialSubmitNotifier, ServiceCredentialSubmitState>(
  ServiceCredentialSubmitNotifier.new,
);

/// Ids que se están retirando ahora mismo.
class ServiceCredentialWithdrawNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// `null` si salió bien; el [Failure] si no.
  Future<Failure?> withdraw(String id) => ref.keepAliveDuring(() async {
        if (state.contains(id)) return null;
        state = {...state, id};
        final result =
            await ref.read(serviceCredentialsRepositoryProvider).withdraw(id);
        if (!ref.mounted) return null;
        state = {...state}..remove(id);
        return result.fold((failure) => failure, (_) {
          ref.invalidate(myServiceCredentialsProvider);
          return null;
        });
      });
}

final serviceCredentialWithdrawProvider = NotifierProvider.autoDispose<
    ServiceCredentialWithdrawNotifier, Set<String>>(
  ServiceCredentialWithdrawNotifier.new,
);

// ── Cola de revisión ─────────────────────────────────────────────────────────

/// Qué se pide a `GET /service-credentials/review`. Cambiar la pestaña o la
/// búsqueda crea otra lista.
class ReviewQueueQuery extends Equatable {
  const ReviewQueueQuery({
    this.status = ReviewStatusFilter.pending,
    this.search = '',
  });

  final ReviewStatusFilter status;
  final String search;

  @override
  List<Object?> get props => [status, search];
}

/// Lo cargado hasta ahora: páginas recibidas y los metadatos de la primera.
class ReviewQueueState extends Equatable {
  const ReviewQueueState({
    required this.first,
    required this.items,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final ReviewPage first;
  final List<ReviewItem> items;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  ReviewCounts get counts => first.counts;
  int get total => first.total;
  bool get hasMore => items.length < total;

  ReviewQueueState copyWith({
    List<ReviewItem>? items,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) =>
      ReviewQueueState(
        first: first,
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );

  @override
  List<Object?> get props => [first, items, isLoadingMore, loadMoreFailed];
}

class ReviewQueueNotifier extends AsyncNotifier<ReviewQueueState> {
  ReviewQueueNotifier(this.query);

  final ReviewQueueQuery query;

  @override
  Future<ReviewQueueState> build() async {
    final result =
        await ref.read(serviceCredentialsRepositoryProvider).getReviewQueue(
              status: query.status,
              search: query.search,
            );
    return result.fold(
      (failure) => throw failure,
      (page) => ReviewQueueState(first: page, items: page.items),
    );
  }

  /// Pide la página siguiente. Un fallo no tira la lista: deja
  /// [ReviewQueueState.loadMoreFailed] para ofrecer reintento.
  Future<void> loadMore() => ref.keepAliveDuring(() async {
        final current = state.value;
        if (current == null || current.isLoadingMore || !current.hasMore) {
          return;
        }
        state = AsyncData(
          current.copyWith(isLoadingMore: true, loadMoreFailed: false),
        );
        final limit = current.first.limit <= 0 ? 20 : current.first.limit;
        final result =
            await ref.read(serviceCredentialsRepositoryProvider).getReviewQueue(
                  status: query.status,
                  search: query.search,
                  page: (current.items.length ~/ limit) + 1,
                  limit: limit,
                );
        if (!ref.mounted) return;
        state = AsyncData(
          result.fold(
            (_) => current.copyWith(isLoadingMore: false, loadMoreFailed: true),
            (page) {
              final known = {for (final i in current.items) i.id};
              return current.copyWith(
                items: [
                  ...current.items,
                  ...page.items.where((i) => !known.contains(i.id)),
                ],
                isLoadingMore: false,
              );
            },
          ),
        );
      });
}

final reviewQueueProvider = AsyncNotifierProvider.autoDispose
    .family<ReviewQueueNotifier, ReviewQueueState, ReviewQueueQuery>(
  ReviewQueueNotifier.new,
);

/// Cuántas constancias esperan revisión (insignia de las entradas). Pide una
/// sola fila y lee el conteo de `meta`.
final reviewPendingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final result =
      await ref.read(serviceCredentialsRepositoryProvider).getReviewQueue(
            status: ReviewStatusFilter.pending,
            limit: 1,
          );
  return result.fold((failure) => throw failure, (page) => page.counts.pending);
});

/// Detalle de una constancia por revisar. Falla con el [Failure] original.
final reviewDetailProvider =
    FutureProvider.autoDispose.family<ReviewDetail, String>((ref, id) async {
  final result =
      await ref.read(serviceCredentialsRepositoryProvider).getReviewDetail(id);
  return result.fold((failure) => throw failure, (detail) => detail);
});

/// Aprobar o rechazar. Tras una decisión se invalidan la cola, el conteo, el
/// detalle y los candidatos a cargo («Agregar directivo» pasa a «Aprobada»).
class ServiceCredentialReviewActionsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// `null` si salió bien; el [Failure] si no.
  Future<Failure?> approve(String id, {DateTime? expiresAt}) =>
      _run(id, (repo) => repo.approve(id, expiresAt: expiresAt));

  Future<Failure?> reject(String id, {required String reason}) =>
      _run(id, (repo) => repo.reject(id, reason: reason));

  Future<Failure?> _run(
    String id,
    Future<Either<Failure, Unit>> Function(ServiceCredentialsRepository repo)
        action,
  ) =>
      ref.keepAliveDuring(() async {
        if (state) return null;
        state = true;
        final result =
            await action(ref.read(serviceCredentialsRepositoryProvider));
        if (!ref.mounted) return null;
        state = false;
        final failure = result.fold<Failure?>((f) => f, (_) => null);
        // Un 409 (otra persona ya decidió) también deja la cola desfasada.
        ref.invalidate(reviewQueueProvider);
        ref.invalidate(reviewPendingCountProvider);
        ref.invalidate(reviewDetailProvider(id));
        if (failure == null) {
          ref.invalidate(roleCandidatesProvider);
          ref.invalidate(roleCandidateDetailProvider);
        }
        return failure;
      });
}

final serviceCredentialReviewActionsProvider =
    NotifierProvider.autoDispose<ServiceCredentialReviewActionsNotifier, bool>(
  ServiceCredentialReviewActionsNotifier.new,
);
