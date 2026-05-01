import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/club_member.dart';
import '../../domain/entities/join_request.dart';
import '../providers/members_providers.dart';
import '../widgets/join_request_card.dart';
import '../widgets/member_card.dart';
import '../widgets/members_filter_bar.dart';
import 'member_profile_view.dart';
import 'role_assignment_view.dart';

/// Vista principal de Miembros con dos pestañas:
/// 1. Lista de miembros del club
/// 2. Solicitudes de ingreso al club
class MembersView extends ConsumerStatefulWidget {
  const MembersView({super.key});

  @override
  ConsumerState<MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends ConsumerState<MembersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // AsyncNotifier loads automatically via build() — no manual initState trigger needed
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Determina si el usuario actual puede asignar/revocar roles de club.
  bool _canManageClubRoles(WidgetRef ref) {
    final authState = ref.read(authNotifierProvider);
    final user = authState.valueOrNull;
    if (user == null) return false;
    return hasAnyPermission(user, const {
      'club_roles:assign',
      'club_roles:revoke',
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final pendingCount = ref.watch(pendingRequestsCountProvider);
    final isDirector = _canManageClubRoles(ref);
    final clubCtxAsync = ref.watch(clubContextProvider);
    final membersAsync = ref.watch(membersNotifierProvider);

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
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      color: c.text,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'common.back'.tr(),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedUserList,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'members.view.title'.tr(),
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
                    onTap: membersAsync.isLoading
                        ? null
                        : () {
                            ref
                                .read(membersNotifierProvider.notifier)
                                .refresh();
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
                        child: membersAsync.isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.textTertiary,
                                ),
                              )
                            : HugeIcon(
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
                        color: context.sac.shadow,
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
                    Tab(text: 'members.view.members_tab'.tr()),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('members.view.requests_tab'.tr()),
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
                        membersAsync: membersAsync,
                      ),
                      _JoinRequestsTab(
                        clubContext: ctx,
                        isDirector: isDirector,
                        membersAsync: membersAsync,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: SacLoading()),
                error: (error, _) => Center(
                  child: Text(
                    'members.view.club_context_error'.tr(),
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
  final AsyncValue<MembersData> membersAsync;

  const _MembersTab({
    required this.clubContext,
    required this.isDirector,
    required this.membersAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: membersAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (error, _) => _ErrorState(
              message: error.toString(),
              onRetry: () =>
                  ref.read(membersNotifierProvider.notifier).refresh(),
            ),
            data: (_) => membersByClass.isEmpty
                ? _EmptyState(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    title: 'members.view.no_members_title'.tr(),
                    subtitle:
                        'members.view.no_members_subtitle'.tr(),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () =>
                        ref.read(membersNotifierProvider.notifier).refresh(),
                    child: _buildMembersList(
                      context,
                      ref,
                      membersByClass,
                      hPad,
                      isDirector,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Flatten grouped members into a virtualized ListView.builder.
  /// Each group produces: header → spacing → N member cards → spacing.
  Widget _buildMembersList(
    BuildContext context,
    WidgetRef ref,
    Map<String, List<ClubMember>> membersByClass,
    double hPad,
    bool isDirector,
  ) {
    // Flatten into indexed items: (header | member | spacing)
    final entries = membersByClass.entries.toList();
    // Pre-compute flat item count: per group = 1 header + 1 spacing + N members + 1 trailing spacing
    int totalItems = 0;
    for (final entry in entries) {
      totalItems += 2 + entry.value.length; // header + post-header spacing + members
      totalItems += 1; // trailing spacing
    }

    // Map flat index → (groupIndex, localIndex within group)
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
      itemCount: totalItems,
      itemBuilder: (context, flatIndex) {
        int cursor = 0;
        for (final entry in entries) {
          // Header
          if (flatIndex == cursor) {
            return _ClassGroupHeader(
              label: entry.key,
              count: entry.value.length,
            );
          }
          cursor++;

          // Post-header spacing
          if (flatIndex == cursor) {
            return const SizedBox(height: 8);
          }
          cursor++;

          // Member cards
          final membersInGroup = entry.value.length;
          if (flatIndex < cursor + membersInGroup) {
            final memberIndex = flatIndex - cursor;
            final member = entry.value[memberIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MemberCard(
                member: member,
                onTap: () => _openMemberProfile(context, member),
                onAssignRole: isDirector
                    ? () => _openRoleAssignment(context, ref, member)
                    : null,
              ),
            );
          }
          cursor += membersInGroup;

          // Trailing spacing
          if (flatIndex == cursor) {
            return const SizedBox(height: 8);
          }
          cursor++;
        }
        return const SizedBox.shrink();
      },
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
    // Result is ignored here — MembersNotifier.assignRole calls invalidateSelf()
    // internally so the list auto-refreshes via the AsyncNotifier build().
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoleAssignmentView(
          member: member,
          clubContext: clubContext,
        ),
      ),
    );
  }
}

// ── Join Requests Tab ─────────────────────────────────────────────────────────

class _JoinRequestsTab extends ConsumerStatefulWidget {
  final ClubContext clubContext;
  final bool isDirector;
  final AsyncValue<MembersData> membersAsync;

  const _JoinRequestsTab({
    required this.clubContext,
    required this.isDirector,
    required this.membersAsync,
  });

  @override
  ConsumerState<_JoinRequestsTab> createState() => _JoinRequestsTabState();
}

class _JoinRequestsTabState extends ConsumerState<_JoinRequestsTab> {
  /// IDs de solicitudes que están siendo procesadas (approve o reject en vuelo)
  final Set<String> _processingIds = {};

  @override
  Widget build(BuildContext context) {
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
          child: widget.membersAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (error, _) => _ErrorState(
              message: error.toString(),
              onRetry: () =>
                  ref.read(membersNotifierProvider.notifier).refresh(),
            ),
            data: (_) => filteredRequests.isEmpty
                ? _EmptyState(
                    icon: HugeIcons.strokeRoundedUserAdd01,
                    title: 'members.view.no_requests_title'.tr(),
                    subtitle: 'members.view.no_requests_subtitle'.tr(),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () =>
                        ref.read(membersNotifierProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
                      itemCount: filteredRequests.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final request = filteredRequests[index];
                        final isProcessing =
                            _processingIds.contains(request.assignmentId);
                        final canAct = widget.isDirector &&
                            request.status == JoinRequestStatus.pending &&
                            !isProcessing;
                        return StaggeredListItem(
                          index: index,
                          initialDelay: const Duration(milliseconds: 30),
                          child: JoinRequestCard(
                            request: request,
                            onTap: () =>
                                _openRequestProfile(context, request),
                            onApprove: canAct
                                ? () => _approveRequest(context, request)
                                : null,
                            onReject: canAct
                                ? () => _rejectRequest(context, request)
                                : null,
                          ),
                        );
                      },
                    ),
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
          title: 'members.view.request_profile_title'.tr(),
        ),
      ),
    );
  }

  Future<void> _approveRequest(
    BuildContext context,
    JoinRequest request,
  ) async {
    setState(() => _processingIds.add(request.assignmentId));
    try {
      final success = await ref
          .read(membersNotifierProvider.notifier)
          .approveRequest(request.assignmentId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? tr('members.view.request_approved', namedArgs: {'name': request.fullName})
                  : 'members.view.approve_error'.tr(),
            ),
            backgroundColor:
                success ? AppColors.secondary : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(request.assignmentId));
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    JoinRequest request,
  ) async {
    setState(() => _processingIds.add(request.assignmentId));
    try {
      final success = await ref
          .read(membersNotifierProvider.notifier)
          .rejectRequest(request.assignmentId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? tr('members.view.request_rejected', namedArgs: {'name': request.fullName})
                  : 'members.view.reject_error'.tr(),
            ),
            backgroundColor:
                success ? AppColors.secondary : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(request.assignmentId));
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              'members.view.load_error'.tr(),
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
                text: 'common.retry'.tr(),
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
              'members.view.no_club_title'.tr(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'members.view.no_club_subtitle'.tr(),
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
  State<_JoinRequestSearchBar> createState() => _JoinRequestSearchBarState();
}

class _JoinRequestSearchBarState extends State<_JoinRequestSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filters.searchQuery);
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
              widget.onFiltersChanged(filters.copyWith(searchQuery: value));
            },
            style: TextStyle(fontSize: 14, color: c.text),
            decoration: InputDecoration(
              hintText: 'members.view.search_requests_hint'.tr(),
              hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: c.textTertiary,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
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
                label: 'members.view.all_status'.tr(),
                isActive: filters.statusFilter == null,
                onTap: () => widget
                    .onFiltersChanged(filters.copyWith(clearStatus: true)),
              ),
              const SizedBox(width: 6),
              _StatusFilterChip(
                label: 'members.view.pending_status'.tr(),
                isActive: filters.statusFilter == JoinRequestStatus.pending,
                onTap: () => widget.onFiltersChanged(
                    filters.copyWith(statusFilter: JoinRequestStatus.pending)),
              ),
              const SizedBox(width: 6),
              _StatusFilterChip(
                label: 'members.view.approved_status'.tr(),
                isActive: filters.statusFilter == JoinRequestStatus.approved,
                onTap: () => widget.onFiltersChanged(
                    filters.copyWith(statusFilter: JoinRequestStatus.approved)),
              ),
              const SizedBox(width: 6),
              _StatusFilterChip(
                label: 'members.view.rejected_status'.tr(),
                isActive: filters.statusFilter == JoinRequestStatus.rejected,
                onTap: () => widget.onFiltersChanged(
                    filters.copyWith(statusFilter: JoinRequestStatus.rejected)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppColors.primary : c.textSecondary,
          ),
        ),
      ),
    );
  }
}
