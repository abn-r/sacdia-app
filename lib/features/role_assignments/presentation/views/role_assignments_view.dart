import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/role_assignment.dart';
import '../providers/role_assignments_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Vista de asignaciones de rol del usuario.
///
/// Solo lectura — las asignaciones son iniciadas por administradores.
class RoleAssignmentsView extends ConsumerWidget {
  const RoleAssignmentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(roleAssignmentsProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'role_assignments.view.title'.tr(),
          actions: [
            SacPressable(
              listenOnly: true,
              child: IconButton(
                enableFeedback: false,
                tooltip: 'common.refresh'.tr(),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  color: c.textSecondary,
                  size: 20,
                ),
                onPressed: () => ref.invalidate(roleAssignmentsProvider),
              ),
            ),
          ],
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => assignmentsAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (e, _) => SacErrorState(
              title: userErrorMessage(e),
              padding:
                  SacTopBar.paddingBelowBar(context, const EdgeInsets.all(32)),
              retryLabel: 'role_assignments.view.retry'.tr(),
              onRetry: () => ref.invalidate(roleAssignmentsProvider),
            ),
            data: (assignments) {
              if (assignments.isEmpty) {
                return SacEmptyState(
                  icon: HugeIcons.strokeRoundedUserStar01,
                  title: 'role_assignments.view.empty_title'.tr(),
                  body: 'role_assignments.view.empty_body'.tr(),
                );
              }

              return RefreshIndicator(
                color: SacAccent.of(context).color,
                onRefresh: () async => ref.invalidate(roleAssignmentsProvider),
                child: ListView(
                  padding: SacTopBar.paddingBelowBar(
                      context, const EdgeInsets.all(20)),
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.infoContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                            color: c.onInfoContainer.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedInformationCircle,
                            size: 16,
                            color: c.onInfoContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'role_assignments.view.admin_note'.tr(),
                              style: TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                color: c.onInfoContainer,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...assignments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AssignmentCard(assignment: a),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Assignment Card ───────────────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final RoleAssignment assignment;

  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final statusCfg = _statusConfig(context, assignment.assignmentStatus);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: assignment.assignmentStatus == AssignmentStatus.active
              ? SacAccent.of(context).color.withValues(alpha: 0.3)
              : c.border,
        ),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusCfg.bg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedUserStar01,
                  color: statusCfg.fg,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.roleName ??
                          'role_assignments.view.fallback_role'
                              .tr(namedArgs: {'id': '${assignment.roleId}'}),
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    if (assignment.clubName != null)
                      Text(
                        assignment.sectionName != null
                            ? '${assignment.clubName} — ${assignment.sectionName}'
                            : assignment.clubName!,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'role_assignments.view.fallback_section'.tr(
                            namedArgs: {'id': '${assignment.clubSectionId}'}),
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusBadge(status: assignment.assignmentStatus),
            ],
          ),
          if (assignment.assignedAt != null ||
              assignment.revokedAt != null ||
              assignment.notes != null) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: c.divider),
            const SizedBox(height: 10),
          ],
          if (assignment.assignedAt != null)
            _MetaRow(
              icon: HugeIcons.strokeRoundedCalendarAdd01,
              label: 'role_assignments.view.label_assigned'.tr(),
              value: dateFmt.format(assignment.assignedAt!.toLocal()),
            ),
          if (assignment.revokedAt != null) ...[
            if (assignment.assignedAt != null) const SizedBox(height: 6),
            _MetaRow(
              icon: HugeIcons.strokeRoundedCalendarRemove01,
              label: 'role_assignments.view.label_revoked'.tr(),
              value: dateFmt.format(assignment.revokedAt!.toLocal()),
            ),
          ],
          if (assignment.notes != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedNoteEdit,
                  color: c.textTertiary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    assignment.notes!,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(BuildContext context, AssignmentStatus status) {
    final c = context.sac;
    switch (status) {
      case AssignmentStatus.active:
        return _StatusConfig(bg: c.successContainer, fg: c.onSuccessContainer);
      case AssignmentStatus.revoked:
        return _StatusConfig(bg: c.errorContainer, fg: c.onErrorContainer);
      case AssignmentStatus.pending:
        return _StatusConfig(bg: c.warningContainer, fg: c.onWarningContainer);
    }
  }
}

class _StatusConfig {
  final Color bg;
  final Color fg;

  const _StatusConfig({required this.bg, required this.fg});
}

class _StatusBadge extends StatelessWidget {
  final AssignmentStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case AssignmentStatus.active:
        return SacBadge.success(label: status.label);
      case AssignmentStatus.revoked:
        return SacBadge.error(label: status.label);
      case AssignmentStatus.pending:
        return SacBadge.warning(label: status.label);
    }
  }
}

class _MetaRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        HugeIcon(icon: icon, color: c.textTertiary, size: 14),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: SacFontSize.bodySmall,
            color: c.textTertiary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: SacFontSize.bodySmall,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}
