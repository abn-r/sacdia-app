import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/camporee_approval.dart';
import '../providers/coordinator_providers.dart';
import '../widgets/approval_action_buttons.dart';

/// Vista principal de aprobaciones de camporees.
///
/// Flujo:
///  1. Muestra un selector de camporee (tabs: Local / Unión).
///  2. Al seleccionar uno, carga las inscripciones pendientes.
///  3. Presenta tres sub-tabs: Clubs | Miembros | Pagos.
class CamporeeApprovalsView extends ConsumerStatefulWidget {
  const CamporeeApprovalsView({super.key});

  @override
  ConsumerState<CamporeeApprovalsView> createState() =>
      _CamporeeApprovalsViewState();
}

class _CamporeeApprovalsViewState extends ConsumerState<CamporeeApprovalsView>
    with SingleTickerProviderStateMixin {
  late TabController _scopeTabController;

  static const _scopeTabs = [CamporeeScope.local, CamporeeScope.union];

  @override
  void initState() {
    super.initState();
    _scopeTabController =
        TabController(length: _scopeTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _scopeTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final selected = ref.watch(selectedCamporeeProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: selected == null
            ? const Text('Aprobaciones de Camporees')
            : Text(selected.name, overflow: TextOverflow.ellipsis),
        leading: selected != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    ref.read(selectedCamporeeProvider.notifier).state = null,
              )
            : null,
        bottom: selected == null
            ? TabBar(
                controller: _scopeTabController,
                tabs: _scopeTabs
                    .map((s) => Tab(text: s.displayLabel))
                    .toList(),
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: c.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      body: selected == null
          ? TabBarView(
              controller: _scopeTabController,
              children: _scopeTabs
                  .map((scope) => _CamporeePickerTab(scope: scope))
                  .toList(),
            )
          : _CamporeeApprovalDetail(camporee: selected),
    );
  }
}

// ── Camporee picker tab ───────────────────────────────────────────────────────

/// Muestra la lista de camporees del scope dado para que el coordinador elija.
class _CamporeePickerTab extends ConsumerWidget {
  final CamporeeScope scope;

  const _CamporeePickerTab({required this.scope});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = scope == CamporeeScope.local
        ? ref.watch(localCamporeeListProvider)
        : ref.watch(unionCamporeeListProvider);

    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return listAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return _buildEmpty(context, ref, c, scope);
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (scope == CamporeeScope.local) {
              ref.invalidate(localCamporeeListProvider);
            } else {
              ref.invalidate(unionCamporeeListProvider);
            }
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final camporee = list[index];
              return _CamporeePickerCard(
                camporee: camporee,
                onTap: () {
                  ref.read(selectedCamporeeProvider.notifier).state = camporee;
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: SacLoading()),
      error: (error, _) => _buildError(context, ref, error, scope, c),
    );
  }

  Widget _buildEmpty(
    BuildContext context,
    WidgetRef ref,
    SacColors c,
    CamporeeScope scope,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar04,
            size: 56,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin camporees activos',
            style: TextStyle(fontSize: 16, color: c.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay camporees ${scope.displayLabel.toLowerCase()}es activos',
            style: TextStyle(fontSize: 13, color: c.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    Object error,
    CamporeeScope scope,
    SacColors c,
  ) {
    final msg = error.toString().replaceFirst('Exception: ', '');
    final is403 = msg.contains('permiso') || msg.contains('403');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: is403
                  ? HugeIcons.strokeRoundedLockKey
                  : HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              is403 ? 'Acceso restringido' : 'Error al cargar camporees',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              is403
                  ? 'Solo coordinadores con permisos attendance:approve_late pueden acceder.'
                  : msg,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (!is403) ...[
              const SizedBox(height: 24),
              SacButton.primary(
                text: 'Reintentar',
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: () {
                  if (scope == CamporeeScope.local) {
                    ref.invalidate(localCamporeeListProvider);
                  } else {
                    ref.invalidate(unionCamporeeListProvider);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Camporee picker card ──────────────────────────────────────────────────────

class _CamporeePickerCard extends StatelessWidget {
  final CamporeeItem camporee;
  final VoidCallback onTap;

  const _CamporeePickerCard({
    required this.camporee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateRange =
        '${dateFormat.format(camporee.startDate)} - ${dateFormat.format(camporee.endDate)}';

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar04,
                    size: 22,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camporee.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRange,
                      style:
                          TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Camporee approval detail ──────────────────────────────────────────────────

/// Vista de detalle: muestra los 3 tabs (Clubs / Miembros / Pagos)
/// con las inscripciones pendientes del [camporee] seleccionado.
class _CamporeeApprovalDetail extends ConsumerStatefulWidget {
  final CamporeeItem camporee;

  const _CamporeeApprovalDetail({required this.camporee});

  @override
  ConsumerState<_CamporeeApprovalDetail> createState() =>
      _CamporeeApprovalDetailState();
}

class _CamporeeApprovalDetailState
    extends ConsumerState<_CamporeeApprovalDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    CamporeeApprovalType.club,
    CamporeeApprovalType.member,
    CamporeeApprovalType.payment,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  CamporeePendingKey get _pendingKey =>
      (camporeeId: widget.camporee.id, scope: widget.camporee.scope);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pendingAsync = ref.watch(camporeePendingProvider(_pendingKey));

    return Column(
      children: [
        // ── Tabs bar ────────────────────────────────────────────────────
        Material(
          color: c.surface,
          child: TabBar(
            controller: _tabController,
            tabs: _tabs.map((t) => Tab(text: t.displayLabel)).toList(),
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: c.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Tab content ─────────────────────────────────────────────────
        Expanded(
          child: pendingAsync.when(
            data: (pending) => TabBarView(
              controller: _tabController,
              children: [
                _ClubsTab(
                  camporee: widget.camporee,
                  items: pending.clubs,
                  pendingKey: _pendingKey,
                ),
                _MembersTab(
                  camporee: widget.camporee,
                  items: pending.members,
                  pendingKey: _pendingKey,
                ),
                _PaymentsTab(
                  camporee: widget.camporee,
                  items: pending.payments,
                  pendingKey: _pendingKey,
                ),
              ],
            ),
            loading: () => const Center(child: SacLoading()),
            error: (error, _) =>
                _buildPendingError(context, ref, error, c),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingError(
    BuildContext context,
    WidgetRef ref,
    Object error,
    SacColors c,
  ) {
    final msg = error.toString().replaceFirst('Exception: ', '');

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
              'Error al cargar aprobaciones',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
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
              onPressed: () => ref.invalidate(camporeePendingProvider(_pendingKey)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Clubs tab ─────────────────────────────────────────────────────────────────

class _ClubsTab extends ConsumerWidget {
  final CamporeeItem camporee;
  final List<CamporeeClubEnrollment> items;
  final CamporeePendingKey pendingKey;

  const _ClubsTab({
    required this.camporee,
    required this.items,
    required this.pendingKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return _buildEmpty(context);

    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          ref.invalidate(camporeePendingProvider(pendingKey)),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _countLabel(context, items.length, 'club', c);
          }
          final item = items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ClubEnrollmentCard(
              camporee: camporee,
              item: item,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            size: 56,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin clubs pendientes',
            style: TextStyle(fontSize: 16, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Members tab ───────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final CamporeeItem camporee;
  final List<CamporeeMemberEnrollment> items;
  final CamporeePendingKey pendingKey;

  const _MembersTab({
    required this.camporee,
    required this.items,
    required this.pendingKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return _buildEmpty(context);

    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          ref.invalidate(camporeePendingProvider(pendingKey)),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _countLabel(context, items.length, 'miembro', c);
          }
          final item = items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemberEnrollmentCard(
              camporee: camporee,
              item: item,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            size: 56,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin miembros pendientes',
            style: TextStyle(fontSize: 16, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Payments tab ──────────────────────────────────────────────────────────────

class _PaymentsTab extends ConsumerWidget {
  final CamporeeItem camporee;
  final List<CamporeePaymentEnrollment> items;
  final CamporeePendingKey pendingKey;

  const _PaymentsTab({
    required this.camporee,
    required this.items,
    required this.pendingKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return _buildEmpty(context);

    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          ref.invalidate(camporeePendingProvider(pendingKey)),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _countLabel(context, items.length, 'pago', c);
          }
          final item = items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PaymentEnrollmentCard(
              camporee: camporee,
              item: item,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            size: 56,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin pagos pendientes',
            style: TextStyle(fontSize: 16, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Club enrollment card ──────────────────────────────────────────────────────

class _ClubEnrollmentCard extends ConsumerWidget {
  final CamporeeItem camporee;
  final CamporeeClubEnrollment item;

  const _ClubEnrollmentCard({
    required this.camporee,
    required this.item,
  });

  CamporeeClubKey get _key => (
        camporeeId: item.camporeeId,
        camporeeClubId: item.camporeeClubId,
        scope: camporee.scope,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(camporeeClubApprovalNotifierProvider(_key));

    return _ApprovalCard(
      icon: HugeIcons.strokeRoundedBuilding01,
      iconColor: AppColors.primary,
      title: item.displayName,
      subtitle: item.registeredByName != null
          ? 'Solicitado por ${item.registeredByName}'
          : null,
      date: item.createdAt,
      isLoading: actionState.isLoading,
      onApprove: () => _handleApprove(context, ref),
      onReject: () => _handleReject(context, ref),
    );
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar club'),
        content: Text(
          '¿Confirmas la inscripción de ${item.displayName} al camporee?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier =
        ref.read(camporeeClubApprovalNotifierProvider(_key).notifier);
    final ok = await notifier.approve();

    if (!context.mounted) return;
    showActionSnackbar(
      context,
      message: ok ? 'Club aprobado' : 'Error al aprobar',
      success: ok,
    );
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final reason = await showRejectDialog(
      context: context,
      title: 'Rechazar club',
      confirmMessage:
          '¿Rechazas la inscripción de ${item.displayName} al camporee?',
    );

    if (reason == null || !context.mounted) return;

    final notifier =
        ref.read(camporeeClubApprovalNotifierProvider(_key).notifier);
    final ok = await notifier.reject(rejectionReason: reason);

    if (!context.mounted) return;
    showActionSnackbar(
      context,
      message: ok ? 'Club rechazado' : 'Error al rechazar',
      success: ok,
    );
  }
}

// ── Member enrollment card ────────────────────────────────────────────────────

class _MemberEnrollmentCard extends ConsumerWidget {
  final CamporeeItem camporee;
  final CamporeeMemberEnrollment item;

  const _MemberEnrollmentCard({
    required this.camporee,
    required this.item,
  });

  CamporeeMemberKey get _key => (
        camporeeId: item.camporeeId,
        camporeeMemberId: item.camporeeMemberId,
        scope: camporee.scope,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(camporeeMemberApprovalNotifierProvider(_key));

    return _ApprovalCard(
      icon: HugeIcons.strokeRoundedUser,
      iconColor: AppColors.accent,
      title: item.displayName,
      subtitle: item.clubName,
      date: item.createdAt,
      isLoading: actionState.isLoading,
      onApprove: () => _handleApprove(context, ref),
      onReject: () => _handleReject(context, ref),
    );
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar miembro'),
        content: Text(
          '¿Confirmas la inscripción de ${item.displayName} al camporee?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier =
        ref.read(camporeeMemberApprovalNotifierProvider(_key).notifier);
    final ok = await notifier.approve();

    if (!context.mounted) return;
    showActionSnackbar(
      context,
      message: ok ? 'Miembro aprobado' : 'Error al aprobar',
      success: ok,
    );
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final reason = await showRejectDialog(
      context: context,
      title: 'Rechazar miembro',
      confirmMessage:
          '¿Rechazas la inscripción de ${item.displayName} al camporee?',
    );

    if (reason == null || !context.mounted) return;

    final notifier =
        ref.read(camporeeMemberApprovalNotifierProvider(_key).notifier);
    final ok = await notifier.reject(rejectionReason: reason);

    if (!context.mounted) return;
    showActionSnackbar(
      context,
      message: ok ? 'Miembro rechazado' : 'Error al rechazar',
      success: ok,
    );
  }
}

// ── Payment enrollment card ───────────────────────────────────────────────────

class _PaymentEnrollmentCard extends ConsumerWidget {
  final CamporeeItem camporee;
  final CamporeePaymentEnrollment item;

  const _PaymentEnrollmentCard({
    required this.camporee,
    required this.item,
  });

  CamporeePaymentKey get _key => (
        camporeePaymentId: item.approvalId,
        camporeeId: item.camporeeId,
        scope: camporee.scope,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState =
        ref.watch(camporeePaymentApprovalNotifierProvider(_key));

    return _ApprovalCard(
      icon: HugeIcons.strokeRoundedCreditCard,
      iconColor: AppColors.info,
      title: item.displayName,
      subtitle: _paymentTypeLabel(item.paymentType),
      date: item.createdAt,
      amount: item.amount,
      reference: item.reference,
      isLoading: actionState.isLoading,
      onApprove: () => _handleApprove(context, ref),
      onReject: () => _handleReject(context, ref),
    );
  }

  String _paymentTypeLabel(String type) {
    switch (type) {
      case 'inscription':
        return 'Inscripción';
      case 'materials':
        return 'Materiales';
      default:
        return 'Otro';
    }
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar pago'),
        content: Text(
          '¿Confirmás el pago de \$${item.amount.toStringAsFixed(2)} de ${item.displayName}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final notifier =
        ref.read(camporeePaymentApprovalNotifierProvider(_key).notifier);
    final ok = await notifier.approve();

    if (!context.mounted) return;
    showActionSnackbar(
      context,
      message: ok ? 'Pago aprobado' : 'Error al aprobar',
      success: ok,
    );
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final reason = await showRejectDialog(
      context: context,
      title: 'Rechazar pago',
      confirmMessage:
          '¿Rechazás el pago de \$${item.amount.toStringAsFixed(2)} de ${item.displayName}?',
    );

    if (reason == null || !context.mounted) return;

    final notifier =
        ref.read(camporeePaymentApprovalNotifierProvider(_key).notifier);
    final ok = await notifier.reject(rejectionReason: reason);

    if (!context.mounted) return;
    showActionSnackbar(
      context,
      message: ok ? 'Pago rechazado' : 'Error al rechazar',
      success: ok,
    );
  }
}

// ── Shared approval card ──────────────────────────────────────────────────────

class _ApprovalCard extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final DateTime? date;
  final double? amount;
  final String? reference;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.date,
    this.amount,
    this.reference,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(icon: icon, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style:
                            TextStyle(fontSize: 12, color: c.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Meta info ────────────────────────────────────────────────
          Row(
            children: [
              if (date != null) ...[
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  size: 12,
                  color: c.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(date!.toLocal()),
                  style: TextStyle(fontSize: 11, color: c.textTertiary),
                ),
              ],
              if (amount != null) ...[
                const SizedBox(width: 12),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCreditCard,
                  size: 12,
                  color: c.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '\$${amount!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ],
              if (reference != null && reference!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  'Ref: $reference',
                  style: TextStyle(fontSize: 11, color: c.textTertiary),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // ── Actions ──────────────────────────────────────────────────
          ApprovalActionBar(
            isLoading: isLoading,
            onApprove: onApprove,
            onReject: onReject,
          ),
        ],
      ),
    );
  }
}

// ── Count label helper ────────────────────────────────────────────────────────

Widget _countLabel(
  BuildContext context,
  int count,
  String singular,
  SacColors c,
) {
  final plural = count != 1 ? 's' : '';
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      '$count $singular$plural pendiente$plural',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
      ),
    ),
  );
}
