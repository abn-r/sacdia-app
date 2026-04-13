import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/notifications_remote_data_source.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  return NotificationsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepositoryImpl(
    remoteDataSource: ref.read(notificationsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Inbox state ───────────────────────────────────────────────────────────────

/// Estado del inbox de notificaciones con soporte para paginación.
class NotificationsInboxState {
  final List<NotificationItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final int currentPage;
  final int totalPages;
  final bool hasReachedEnd;

  const NotificationsInboxState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentPage = 0,
    this.totalPages = 1,
    this.hasReachedEnd = false,
  });

  bool get isEmpty => items.isEmpty && !isLoading;

  NotificationsInboxState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    int? currentPage,
    int? totalPages,
    bool? hasReachedEnd,
  }) {
    return NotificationsInboxState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class NotificationsInboxNotifier extends Notifier<NotificationsInboxState> {
  static const _pageSize = 20;
  CancelToken? _currentToken;

  @override
  NotificationsInboxState build() {
    // Carga la primera página al inicializar.
    Future.microtask(() => _loadPage(1, refresh: true));
    return const NotificationsInboxState(isLoading: true);
  }

  /// Carga o recarga desde la primera página.
  Future<void> refresh() => _loadPage(1, refresh: true);

  /// Actualiza optimistamente el estado leído de un item por su deliveryId.
  ///
  /// Si [rollback] es true, revierte isRead al valor anterior (false).
  void updateItemReadState(String deliveryId, {required bool isRead}) {
    final updated = state.items.map((item) {
      if (item.deliveryId == deliveryId) {
        return item.copyWith(
          isRead: isRead,
          readAt: isRead ? DateTime.now() : null,
        );
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  /// Carga la siguiente página si hay más datos disponibles.
  Future<void> loadNextPage() async {
    if (state.isLoadingMore || state.hasReachedEnd) return;
    await _loadPage(state.currentPage + 1, refresh: false);
  }

  Future<void> _loadPage(int page, {required bool refresh}) async {
    if (refresh) {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    _currentToken?.cancel();
    _currentToken = CancelToken();

    final repository = ref.read(notificationsRepositoryProvider);
    final result = await repository.getHistory(
      page: page,
      limit: _pageSize,
      cancelToken: _currentToken,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
      (data) {
        final newItems = refresh
            ? data.items
            : [...state.items, ...data.items];

        state = state.copyWith(
          items: newItems,
          isLoading: false,
          isLoadingMore: false,
          currentPage: page,
          totalPages: data.totalPages,
          hasReachedEnd: page >= data.totalPages,
          clearError: true,
        );
      },
    );
  }
}

final notificationsInboxProvider =
    NotifierProvider<NotificationsInboxNotifier, NotificationsInboxState>(
  NotificationsInboxNotifier.new,
);
