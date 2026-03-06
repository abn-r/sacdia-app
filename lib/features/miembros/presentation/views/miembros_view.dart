import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/club_member.dart';
import '../../domain/entities/join_request.dart';
import '../providers/miembros_providers.dart';
import '../widgets/join_request_card.dart';
import '../widgets/member_card.dart';
import '../widgets/members_filter_bar.dart';
import 'member_profile_view.dart';
import 'role_assignment_view.dart';

/// Vista principal de Miembros con dos pestañas:
/// 1. Lista de miembros del club
/// 2. Solicitudes de ingreso al club
class MiembrosView extends ConsumerStatefulWidget {
  const MiembrosView({super.key});

  @override
  ConsumerState<MiembrosView> createState() => _MiembrosViewState();
}

class _MiembrosViewState extends ConsumerState<MiembrosView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Cargar datos la primera vez si hay contexto de club disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final clubCtxAsync = ref.read(clubContextProvider);
    clubCtxAsync.whenData((ctx) {
      if (ctx != null) {
        ref.read(miembrosNotifierProvider.notifier).refresh(ctx);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Determina si el usuario actual es Director o Subdirector
  bool _isDirectorOrSubdirector(WidgetRef ref) {
    final authState = ref.read(authNotifierProvider);
    final user = authState.valueOrNull;
    if (user == null) return false;
    final metadata = user.metadata;
    if (metadata == null) return false;
    final roles = metadata['roles'] as List<dynamic>?;
    if (roles == null) return false;
    return roles.any((r) =>
        r == 'director' ||
        r == 'deputy_director' ||
        r == 'secretary');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final pendingCount = ref.watch(pendingRequestsCountProvider);
    final isDirector = _isDirectorOrSubdirector(ref);
    final clubCtxAsync = ref.watch(clubContextProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 4),
              child: Row(
                children: [
                  Text(
                    'Miembros',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  GestureDetector(
                    onTap: () {
                      clubCtxAsync.whenData((ctx) {
                        if (ctx != null) {
                          ref
                              .read(miembrosNotifierProvider.notifier)
                              .refresh(ctx);
                        }
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedRefresh,
                          color: c.textTertiary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab bar ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: c.text,
                  unselectedLabelColor: c.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.all(4),
                  tabs: [
                    const Tab(text: 'Miembros'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Solicitudes'),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 6),
                            _PendingBadge(count: pendingCount),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Tab content ────────────────────────────────────────────
            Expanded(
              child: clubCtxAsync.when(
                data: (ctx) {
                  if (ctx == null) {
                    return _NoClubState();
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _MembersTab(
                        clubContext: ctx,
                        isDirector: isDirector,
                      ),
                      _JoinRequestsTab(
                        clubContext: ctx,
                        isDirector: isDirector,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: SacLoading()),
                error: (error, _) => Center(
                  child: Text(
                    'Error al cargar el contexto del club',
                    style: TextStyle(color: context.sac.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Members Tab ───────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final ClubContext clubContext;
  final bool isDirector;

  const _MembersTab({
    required this.clubContext,
    required this.isDirector,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(miembrosNotifierProvider);
    final membersByClass = ref.watch(membersByClassProvider);
    final hPad = Responsive.horizontalPadding(context);

    return Column(
      children: [
        // ── Filter bar ──────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
          child: const MembersFilterBar(),
        ),

        // ── Content ─────────────────────────────────────────────────
        Expanded(
          child: state.isLoading
              ? const Center(child: SacLoading())
              : state.error != null && state.members.isEmpty
                  ? _ErrorState(
                      message: state.error!,
                      onRetry: () => ref
                          .read(miembrosNotifierProvider.notifier)
                          .loadMembers(clubContext),
                    )
                  : membersByClass.isEmpty
                      ? _EmptyState(
                          icon: HugeIcons.strokeRoundedUserGroup,
                          title: 'Sin miembros',
                          subtitle:
                              'No se encontraron miembros con los filtros actuales.',
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => ref
                              .read(miembrosNotifierProvider.notifier)
                              .loadMembers(clubContext),
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                                hPad, 4, hPad, 24),
                            children: [
                              for (final entry
                                  in membersByClass.entries) ...[
                                // Class group header
                                _ClassGroupHeader(
                                    label: entry.key,
                                    count: entry.value.length),
                                const SizedBox(height: 8),
                                // Member cards
                                ...entry.value.asMap().entries.map(
                                  (e) => StaggeredListItem(
                                    index: e.key,
                                    initialDelay:
                                        const Duration(milliseconds: 30),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 10),
                                      child: MemberCard(
                                        member: e.value,
                                        onTap: () => _openMemberProfile(
                                            context, e.value),
                                        onAssignRole: isDirector
                                            ? () => _openRoleAssignment(
                                                  context,
                                                  ref,
                                                  e.value,
                                                )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
        ),
      ],
    );
  }

  void _openMemberProfile(BuildContext context, ClubMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberProfileView(member: member),
      ),
    );
  }

  Future<void> _openRoleAssignment(
    BuildContext context,
    WidgetRef ref,
    ClubMember member,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoleAssignmentView(
          member: member,
          clubContext: clubContext,
        ),
      ),
    );

    if (result == true) {
      ref.read(miembrosNotifierProvider.notifier).loadMembers(clubContext);
    }
  }
}

// ── Join Requests Tab ─────────────────────────────────────────────────────────

class _JoinRequestsTab extends ConsumerWidget {
  final ClubContext clubContext;
  final bool isDirector;

  const _JoinRequestsTab({
    required this.clubContext,
    required this.isDirector,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(miembrosNotifierProvider);
    final filteredRequests = ref.watch(filteredJoinRequestsProvider);
    final filters = ref.watch(joinRequestFiltersProvider);
    final hPad = Responsive.horizontalPadding(context);

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
          child: _JoinRequestSearchBar(
            filters: filters,
            onFiltersChanged: (updated) {
              ref.read(joinRequestFiltersProvider.notifier).state = updated;
            },
          ),
        ),

        // ── Content ─────────────────────────────────────────────────
        Expanded(
          child: state.isLoadingRequests
              ? const Center(child: SacLoading())
              : state.requestsError != null && state.joinRequests.isEmpty
                  ? _ErrorState(
                      message: state.requestsError!,
                      onRetry: () => ref
                          .read(miembrosNotifierProvider.notifier)
                          .loadJoinRequests(clubContext),
                    )
                  : filteredRequests.isEmpty
                      ? _EmptyState(
                          icon: HugeIcons.strokeRoundedUserAdd01,
                          title: 'Sin solicitudes',
                          subtitle:
                              'No hay solicitudes de ingreso pendientes.',
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => ref
                              .read(miembrosNotifierProvider.notifier)
                              .loadJoinRequests(clubContext),
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                                hPad, 4, hPad, 24),
                            itemCount: filteredRequests.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final request = filteredRequests[index];
                              return StaggeredListItem(
                                index: index,
                                initialDelay:
                                    const Duration(milliseconds: 30),
                                child: JoinRequestCard(
                                  request: request,
                                  onTap: () => _openRequestProfile(
                                      context, request),
                                  onApprove: isDirector &&
                                          request.status ==
                                              JoinRequestStatus.pending
                                      ? () => _approveRequest(
                                          context, ref, request)
                                      : null,
                                  onReject: isDirector &&
                                          request.status ==
                                              JoinRequestStatus.pending
                                      ? () => _rejectRequest(
                                          context, ref, request)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  void _openRequestProfile(BuildContext context, JoinRequest request) {
    // Convertir la solicitud en un ClubMember parcial para reusar la vista
    final member = ClubMember(
      userId: request.userId,
      name: request.name,
      paternalSurname: request.paternalSurname,
      maternalSurname: request.maternalSurname,
      avatar: request.avatar,
      email: request.email,
      isEnrolled: false,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberProfileView(
          member: member,
          title: 'Perfil del solicitante',
        ),
      ),
    );
  }

  Future<void> _approveRequest(
    BuildContext context,
    WidgetRef ref,
    JoinRequest request,
  ) async {
    final success = await ref
        .read(miembrosNotifierProvider.notifier)
        .approveRequest(request.id, clubContext);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Solicitud de ${request.fullName} aprobada'
                : 'Error al aprobar la solicitud',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    WidgetRef ref,
    JoinRequest request,
  ) async {
    final success = await ref
        .read(miembrosNotifierProvider.notifier)
        .rejectRequest(request.id, clubContext);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Solicitud de ${request.fullName} rechazada'
                : 'Error al rechazar la solicitud',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

/// Badge con el número de solicitudes pendientes
class _PendingBadge extends StatelessWidget {
  final int count;

  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Header de grupo de clase con label y conteo de miembros
class _ClassGroupHeader extends StatelessWidget {
  final String label;
  final int count;

  const _ClassGroupHeader({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textTertiary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Estado vacío genérico
class _EmptyState extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: icon, size: 56, color: c.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de error con botón de reintento
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SacButton.primary(
                text: 'Reintentar',
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado cuando el usuario no tiene club asignado
class _NoClubState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedBuilding01,
              size: 56,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin club asignado',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Debes pertenecer a un club para ver los miembros.',
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de búsqueda para solicitudes de ingreso
class _JoinRequestSearchBar extends StatefulWidget {
  final JoinRequestFilters filters;
  final ValueChanged<JoinRequestFilters> onFiltersChanged;

  const _JoinRequestSearchBar({
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  State<_JoinRequestSearchBar> createState() =>
      _JoinRequestSearchBarState();
}

class _JoinRequestSearchBarState extends State<_JoinRequestSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final filters = widget.filters;

    return Column(
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: TextField(
            controller: _controller,
            onChanged: (value) {
              widget.onFiltersChanged(
                  filters.copyWith(searchQuery: value));
            },
            style: TextStyle(fontSize: 14, color: c.text),
            decoration: InputDecoration(
              hintText: 'Buscar solicitante...',
              hintStyle:
                  TextStyle(color: c.textTertiary, fontSize: 14),
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: c.textTertiary,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Status filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatusFilterChip(
                label: 'Todos',
                isActive: filters.statusFilter == null,
                onTap: () => widget.onFiltersChanged(
                    filters.copyWith(clearStatus: true)),
              ),
              const SizedBox(width: 6),
              _StatusFilterChip(
                label: 'Pendientes',
                isActive:
                    filters.statusFilter == JoinRequestStatus.pending,
                onTap: () => widget.onFiltersChanged(filters.copyWith(
                    statusFilter: JoinRequestStatus.pending)),
              ),
              const SizedBox(width: 6),
              _StatusFilterChip(
                label: 'Aprobadas',
                isActive:
                    filters.statusFilter == JoinRequestStatus.approved,
                onTap: () => widget.onFiltersChanged(filters.copyWith(
                    statusFilter: JoinRequestStatus.approved)),
              ),
              const SizedBox(width: 6),
              _StatusFilterChip(
                label: 'Rechazadas',
                isActive:
                    filters.statusFilter == JoinRequestStatus.rejected,
                onTap: () => widget.onFiltersChanged(filters.copyWith(
                    statusFilter: JoinRequestStatus.rejected)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : c.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primaryLight : c.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppColors.primary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
