import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../providers/notifications_providers.dart';
import '../providers/unread_notifications_count_provider.dart';
import '../widgets/notification_card.dart';

/// Pantalla de historial/bandeja de notificaciones.
///
/// - Lista paginada de notificaciones (más recientes primero)
/// - Pull-to-refresh
/// - Carga incremental al llegar al final de la lista (load more)
/// - Estado vacío, de carga (skeleton) y de error con retry
/// - AppBar con badge de no-leídas y acción "marcar todas como leídas"
class NotificationsInboxView extends ConsumerStatefulWidget {
  const NotificationsInboxView({super.key});

  @override
  ConsumerState<NotificationsInboxView> createState() =>
      _NotificationsInboxViewState();
}

class _NotificationsInboxViewState
    extends ConsumerState<NotificationsInboxView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.offset >= threshold) {
      ref.read(notificationsInboxProvider.notifier).loadNextPage();
    }
  }

  Future<void> _markAllAsRead() async {
    final repository = ref.read(notificationsRepositoryProvider);
    final result = await repository.markAllAsRead();
    result.fold(
      (_) {
        // On failure, nothing to roll back — just let the state remain.
      },
      (_) {
        ref.read(unreadNotificationsCountProvider.notifier).setZero();
        ref.invalidate(notificationsInboxProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxState = ref.watch(notificationsInboxProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Notificaciones',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
        ),
        actions: [
          // Bell icon with unread badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: null, // Decorative — tapping the list navigates
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedNotification01,
                  size: 22,
                  color: c.text,
                ),
                tooltip: 'Notificaciones',
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Mark all as read
          if (unreadCount > 0)
            IconButton(
              onPressed: inboxState.isLoading ? null : _markAllAsRead,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkSquare01,
                size: 22,
                color: c.text,
              ),
              tooltip: 'Marcar todas como leídas',
            ),
          // Refresh
          IconButton(
            onPressed: inboxState.isLoading
                ? null
                : () =>
                    ref.read(notificationsInboxProvider.notifier).refresh(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 22,
              color: c.text,
            ),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(context, inboxState, c),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationsInboxState state,
    SacColors c,
  ) {
    // Estado de carga inicial — mostrar skeletons
    if (state.isLoading && state.items.isEmpty) {
      return _buildSkeletonList(c);
    }

    // Estado de error sin datos cargados
    if (state.errorMessage != null && state.items.isEmpty) {
      return _buildError(context, state.errorMessage!, c);
    }

    // Estado vacío
    if (state.isEmpty) {
      return _buildEmpty(context, c);
    }

    // Lista con datos
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(notificationsInboxProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        // +1 para el footer de "cargando más" o el indicador de fin de lista
        itemCount: state.items.length + 1,
        itemBuilder: (context, index) {
          if (index < state.items.length) {
            return NotificationCard(notification: state.items[index]);
          }

          // Footer
          return _buildListFooter(state, c);
        },
      ),
    );
  }

  Widget _buildSkeletonList(SacColors c) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, __) => const NotificationCardSkeleton(),
    );
  }

  Widget _buildEmpty(BuildContext context, SacColors c) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedNotification01,
              size: 64,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes notificaciones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando recibas notificaciones, van a aparecer acá.',
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    String errorMessage,
    SacColors c,
  ) {
    final msg = errorMessage.replaceFirst('Exception: ', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar notificaciones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: () =>
                  ref.read(notificationsInboxProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListFooter(NotificationsInboxState state, SacColors c) {
    // Cargando más elementos
    if (state.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    // Error al cargar más (pero ya hay items)
    if (state.errorMessage != null && state.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Center(
          child: TextButton.icon(
            onPressed: () =>
                ref.read(notificationsInboxProvider.notifier).loadNextPage(),
            icon: Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
            label: Text(
              'Error al cargar más. Tocar para reintentar.',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
        ),
      );
    }

    // Fin de la lista
    if (state.hasReachedEnd && state.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '— Fin del historial —',
            style: TextStyle(fontSize: 12, color: c.textTertiary),
          ),
        ),
      );
    }

    return const SizedBox(height: 24);
  }
}
