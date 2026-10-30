import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/consent/consent_error_messages.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/fixed_input_icon_slot.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/club_member.dart';
import '../../domain/entities/join_request.dart';
import '../providers/members_providers.dart';
import '../widgets/join_request_card.dart';
import '../widgets/member_card.dart';
import '../widgets/member_class_group_header.dart';
import '../widgets/members_filter_bar.dart';
import '../widgets/members_mode_switcher.dart';
import '../utils/consent_access.dart';
import '../utils/create_minor_access.dart';
import 'annual_continuations_view.dart';
import 'create_minor_view.dart';
import 'consent_verification_view.dart';
import 'member_profile_view.dart';
import 'role_assignment_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';

/// The mode the members screen shows. Without `club_members:approve` only
/// the member list (mode 0) exists; a verify-only reviewer (`consent:verify`)
/// also gets the requests (mode 1) but never the not-enrolled list (mode 2).
int effectiveMembersMode(
  int mode, {
  required bool canApprove,
  bool canVerify = false,
}) {
  if (canApprove) return mode;
  if (canVerify) return mode == 1 ? 1 : 0;
  return 0;
}

/// Vista principal de Miembros.
/// Modos: miembros, solicitudes, y no inscritos si hay `club_members:approve`.
class MembersView extends ConsumerStatefulWidget {
  /// Modo con el que abre (0 miembros, 1 solicitudes). Si el usuario no tiene
  /// acceso al modo, [effectiveMembersMode] lo devuelve a la lista.
  final int initialMode;

  const MembersView({super.key, this.initialMode = 0});

  @override
  ConsumerState<MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends ConsumerState<MembersView> {
  late int _mode = widget.initialMode;

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

  /// Qué puede hacer el usuario con las solicitudes de ingreso: aprobar (y las
  /// continuaciones anuales), solo verificar fichas (`consent:verify`) o nada.
  JoinRequestsAccess _requestsAccess(WidgetRef ref) =>
      joinRequestsAccess(ref.read(authNotifierProvider).valueOrNull);

  /// Abre el alta de un menor; al volver la lista ya se refrescó (la vista
  /// invalida `membersNotifierProvider` al crear).
  Future<void> _openCreateMinor(BuildContext context, int sectionId) {
    return Navigator.push<void>(
      context,
      SacSharedAxisRoute<void>(
        builder: (_) => CreateMinorView(clubSectionId: sectionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final pendingCount = ref.watch(pendingRequestsCountProvider);
    final isDirector = _canManageClubRoles(ref);
    final access = _requestsAccess(ref);
    final canContinue = access == JoinRequestsAccess.approve;
    final verifyOnly = access == JoinRequestsAccess.verifyOnly;
    final canRequests = access != JoinRequestsAccess.none;
    // Continuations need club_members:approve and the requests need that or
    // consent:verify; without them the API answers 403 and only the member
    // list is left.
    final mode = effectiveMembersMode(
      _mode,
      canApprove: canContinue,
      canVerify: verifyOnly,
    );
    if (_mode != mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mode != mode) setState(() => _mode = mode);
      });
    }
    final continuationsAsync =
        canContinue ? ref.watch(annualContinuationsNotifierProvider) : null;
    final pendingContinuations =
        continuationsAsync?.valueOrNull?.items.length ?? 0;
    final clubCtxAsync = ref.watch(clubContextProvider);
    final membersAsync = ref.watch(membersNotifierProvider);
    // "Registrar un menor": permiso `dependents:create` Y bandera del servidor.
    final registerSectionId =
        canRegisterMinor(ref.watch(authNotifierProvider).valueOrNull)
            ? clubCtxAsync.valueOrNull?.sectionId
            : null;
    final onContinuations = canContinue && mode == 2;
    final fadeDuration = SacMotion.reducedFade;
    final refreshing = onContinuations
        ? (continuationsAsync?.isLoading ?? false)
        : membersAsync.isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'members.view.title'.tr(),
          onBack: () => Navigator.of(context).maybePop(),
          titleIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedUserList,
            size: 22,
            color: SacAccent.of(context).color,
          ),
          actions: [
            if (registerSectionId != null)
              SacPressable(
                listenOnly: true,
                child: IconButton(
                  enableFeedback: false,
                  tooltip: 'members.create_minor.entry'.tr(),
                  onPressed: () => _openCreateMinor(context, registerSectionId),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedUserAdd01,
                    color: c.textTertiary,
                    size: 18,
                  ),
                ),
              ),
            SacPressable(
              listenOnly: true,
              child: IconButton(
                enableFeedback: false,
                onPressed: refreshing
                    ? null
                    : () {
                        if (onContinuations) {
                          ref.invalidate(annualContinuationsNotifierProvider);
                        } else {
                          ref.read(membersNotifierProvider.notifier).refresh();
                        }
                      },
                icon: refreshing
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
          ],
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            child: Column(
              children: [
                if (canRequests)
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                    child: MembersModeSwitcher(
                      index: mode,
                      onChanged: (next) => setState(() => _mode = next),
                      showContinuations: canContinue,
                      pendingRequests: pendingCount,
                      pendingContinuations: pendingContinuations,
                    ),
                  ),
                Expanded(
                  child: clubCtxAsync.when(
                    data: (ctx) {
                      if (ctx == null) {
                        return _NoClubState();
                      }
                      final pages = <Widget>[
                        _MembersTab(
                          clubContext: ctx,
                          isDirector: isDirector,
                          membersAsync: membersAsync,
                        ),
                        if (canRequests)
                          _JoinRequestsTab(
                            clubContext: ctx,
                            canApprove: canContinue,
                            membersAsync: membersAsync,
                            verifyOnly: verifyOnly,
                          ),
                        if (canContinue) const AnnualContinuationsBody(),
                      ];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          for (var i = 0; i < pages.length; i++)
                            IgnorePointer(
                              ignoring: mode != i,
                              child: AnimatedOpacity(
                                opacity: mode == i ? 1 : 0,
                                duration: fadeDuration,
                                curve: SacMotion.easeOut,
                                child: pages[i],
                              ),
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
    final c = context.sac;

    return Column(
      children: [
        ColoredBox(
          color: c.background,
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
            child: const MembersFilterBar(),
          ),
        ),
        Expanded(
          child: ClipRect(
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
                      subtitle: 'members.view.no_members_subtitle'.tr(),
                    )
                  : RefreshIndicator(
                      color: SacAccent.of(context).color,
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
      totalItems +=
          2 + entry.value.length; // header + post-header spacing + members
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
            return MemberClassGroupHeader(
              label: entry.key,
              count: entry.value.length,
            );
          }
          cursor++;

          // Post-header spacing
          if (flatIndex == cursor) {
            return const SizedBox(height: 6);
          }
          cursor++;

          // Member cards
          final membersInGroup = entry.value.length;
          if (flatIndex < cursor + membersInGroup) {
            final memberIndex = flatIndex - cursor;
            final member = entry.value[memberIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
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
            return const SizedBox(height: 6);
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
      SacSharedAxisRoute(
        builder: (_) => MemberProfileView(member: member),
      ),
    );
  }

  Future<void> _openRoleAssignment(
    BuildContext context,
    WidgetRef ref,
    ClubMember member,
  ) async {
    // Un menor con solicitud pendiente y consentimiento sin verificar: si el
    // backend rechaza el cargo (409 MR_CONSENT_NOT_VERIFIED) la vista ofrece
    // abrir la verificación de esa solicitud.
    final requests =
        ref.read(membersNotifierProvider).valueOrNull?.joinRequests ??
            const <JoinRequest>[];
    final pendingConsent = requests
        .where((r) => r.userId == member.userId && r.consentPending)
        .firstOrNull;

    // Result is ignored here — MembersNotifier.assignRole calls invalidateSelf()
    // internally so the list auto-refreshes via the AsyncNotifier build().
    await Navigator.push<bool>(
      context,
      SacSharedAxisRoute(
        builder: (_) => RoleAssignmentView(
          member: member,
          clubContext: clubContext,
          pendingConsentRequest: pendingConsent,
        ),
      ),
    );
  }
}

// ── Join Requests Tab ─────────────────────────────────────────────────────────

class _JoinRequestsTab extends ConsumerStatefulWidget {
  final ClubContext clubContext;

  /// `club_members:approve`: approving and rejecting is a member permission,
  /// not a role-management one (a deputy director holds it too).
  final bool canApprove;
  final AsyncValue<MembersData> membersAsync;

  /// Solo `consent:verify`: el servidor entrega solo los menores con la ficha
  /// por verificar y aquí no se aprueba ni se rechaza nada.
  final bool verifyOnly;

  const _JoinRequestsTab({
    required this.clubContext,
    required this.canApprove,
    required this.membersAsync,
    this.verifyOnly = false,
  });

  @override
  ConsumerState<_JoinRequestsTab> createState() => _JoinRequestsTabState();
}

class _JoinRequestsTabState extends ConsumerState<_JoinRequestsTab> {
  /// IDs de solicitudes que están siendo procesadas (approve o reject en vuelo)
  final Set<String> _processingIds = {};

  /// El texto vacío debe reflejar el filtro activo: "pendientes" solo aplica
  /// cuando se filtra por pendientes.
  String _emptySubtitleKey(JoinRequestFilters filters) {
    if (filters.searchQuery.isNotEmpty) {
      return 'members.view.no_requests_filtered_subtitle';
    }
    return switch (filters.statusFilter) {
      null => 'members.view.no_requests_any_subtitle',
      JoinRequestStatus.pending => 'members.view.no_requests_subtitle',
      _ => 'members.view.no_requests_filtered_subtitle',
    };
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests = ref.watch(filteredJoinRequestsProvider);
    final filters = ref.watch(joinRequestFiltersProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Column(
      children: [
        if (widget.verifyOnly)
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
            child: Text(
              'members.view.verify_only_hint'.tr(),
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ),
        ColoredBox(
          color: c.background,
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
            child: _JoinRequestSearchBar(
              filters: filters,
              onFiltersChanged: (updated) {
                ref.read(joinRequestFiltersProvider.notifier).state = updated;
              },
            ),
          ),
        ),
        Expanded(
          child: ClipRect(
            child: widget.membersAsync.when(
              loading: () => const Center(child: SacLoading()),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () =>
                    ref.read(membersNotifierProvider.notifier).refresh(),
              ),
              data: (data) => widget.verifyOnly && data.requestsScopeDenied
                  ? _EmptyState(
                      icon: HugeIcons.strokeRoundedLockKey,
                      title: 'members.view.verify_scope_title'.tr(),
                      subtitle: 'members.view.verify_scope_subtitle'.tr(),
                    )
                  : filteredRequests.isEmpty
                      ? _EmptyState(
                          icon: widget.verifyOnly
                              ? HugeIcons.strokeRoundedFileVerified
                              : HugeIcons.strokeRoundedUserAdd01,
                          title: widget.verifyOnly
                              ? 'members.view.verify_empty_title'.tr()
                              : 'members.view.no_requests_title'.tr(),
                          subtitle:
                              widget.verifyOnly && filters.searchQuery.isEmpty
                                  ? 'members.view.verify_empty_subtitle'.tr()
                                  : _emptySubtitleKey(filters).tr(),
                        )
                      : RefreshIndicator(
                          color: SacAccent.of(context).color,
                          onRefresh: () => ref
                              .read(membersNotifierProvider.notifier)
                              .refresh(),
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
                            itemCount: filteredRequests.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final request = filteredRequests[index];
                              final isProcessing =
                                  _processingIds.contains(request.assignmentId);
                              if (widget.verifyOnly) {
                                // Solo se verifica la ficha: ni aprobar ni rechazar,
                                // y la fila abre la verificación (no el perfil, que
                                // este permiso no necesariamente puede leer).
                                final verify = request.consentPending
                                    ? () => _openConsentVerification(
                                          context,
                                          request,
                                        )
                                    : null;
                                return JoinRequestCard(
                                  request: request,
                                  onTap: verify,
                                  onVerify: verify,
                                );
                              }
                              final canAct = widget.canApprove &&
                                  request.status == JoinRequestStatus.pending &&
                                  !isProcessing;
                              return JoinRequestCard(
                                request: request,
                                onTap: () =>
                                    _openRequestProfile(context, request),
                                onApprove: canAct
                                    ? () => _approveRequest(context, request)
                                    : null,
                                onReject: canAct
                                    ? () => _rejectRequest(context, request)
                                    : null,
                              );
                            },
                          ),
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
      SacSharedAxisRoute(
        builder: (_) => MemberProfileView(
          member: member,
          title: 'members.view.request_profile_title'.tr(),
        ),
      ),
    );
  }

  /// Abre la verificación de la ficha firmada de un menor (FP-76).
  Future<void> _openConsentVerification(
    BuildContext context,
    JoinRequest request,
  ) {
    return Navigator.push<bool>(
      context,
      SacSharedAxisRoute<bool>(
        builder: (_) => ConsentVerificationView(
          request: request,
          // Solo verificar: nunca se manda `approve: true` sin el permiso.
          canApprove: !widget.verifyOnly &&
              canApproveJoinRequests(
                ref.read(authNotifierProvider).valueOrNull,
              ),
        ),
      ),
    );
  }

  Future<void> _approveRequest(
    BuildContext context,
    JoinRequest request,
  ) async {
    // Un menor sin ficha verificada no se aprueba directo (el backend lo
    // rechazaría con 409 MR_CONSENT_NOT_VERIFIED): se abre la verificación.
    if (request.consentPending) {
      await _openConsentVerification(context, request);
      return;
    }

    setState(() => _processingIds.add(request.assignmentId));
    try {
      final failure = await ref
          .read(membersNotifierProvider.notifier)
          .approveRequestOrFailure(request.assignmentId);

      if (!context.mounted) return;
      if (failure == null) {
        SacSnackBar.show(
          context,
          tr('members.view.request_approved',
              namedArgs: {'name': request.fullName}),
        );
        return;
      }

      // La lista estaba desactualizada: era un menor con consentimiento
      // pendiente. Se explica y se abre la verificación.
      if (failure.errorCode == 'MR_CONSENT_NOT_VERIFIED') {
        SacSnackBar.show(
          context,
          'members.consent.approve_blocked'.tr(),
          isError: true,
        );
        await _openConsentVerification(context, request);
        return;
      }

      SacSnackBar.show(
        context,
        consentErrorKey(failure.errorCode) != null
            ? consentErrorMessage(failure)
            : 'members.view.approve_error'.tr(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(request.assignmentId));
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    JoinRequest request,
  ) async {
    // Rejecting is final for the applicant, so a stray tap must not do it.
    final confirmed = await SacDialog.show(
      context,
      title: 'members.view.reject_confirm_title'.tr(),
      content: tr('members.view.reject_confirm_body',
          namedArgs: {'name': request.fullName}),
      confirmLabel: 'members.view.reject_confirm_action'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingIds.add(request.assignmentId));
    try {
      final success = await ref
          .read(membersNotifierProvider.notifier)
          .rejectRequest(request.assignmentId);

      if (context.mounted) {
        SacSnackBar.show(
          context,
          success
              ? tr('members.view.request_rejected',
                  namedArgs: {'name': request.fullName})
              : 'members.view.reject_error'.tr(),
          isError: !success,
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(request.assignmentId));
    }
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

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
    return SacEmptyState(
      icon: icon,
      title: title,
      body: subtitle,
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
              prefixIconConstraints: FixedInputIconSlot.constraints,
              prefixIcon: FixedInputIconSlot(
                icon: HugeIcons.strokeRoundedSearch01,
                color: c.textTertiary,
                iconSize: 20,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            ),
          ),
        ),

        // No status chips: GET membership-requests only returns pending
        // requests, so approved/rejected filters were always empty.
      ],
    );
  }
}
