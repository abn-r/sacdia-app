import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/role_assignment.dart';
import '../providers/role_assignments_providers.dart';

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
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Mis roles asignados',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: c.textSecondary,
              size: 20,
            ),
            onPressed: () => ref.invalidate(roleAssignmentsProvider),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(roleAssignmentsProvider),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return const _EmptyBody();
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(roleAssignmentsProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        size: 16,
                        color: AppColors.accentDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Las asignaciones son gestionadas por los administradores del club.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accentDark,
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
    final statusCfg = _statusConfig(assignment.assignmentStatus);
    final dateFmt = DateFormat('dd/MM/yyyy', 'es');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: assignment.assignmentStatus == AssignmentStatus.active
              ? AppColors.primary.withValues(alpha: 0.3)
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
                  borderRadius: BorderRadius.circular(10),
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
                      assignment.roleName ?? 'Rol #${assignment.roleId}',
                      style: TextStyle(
                        fontSize: 15,
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
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'Sección #${assignment.clubSectionId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusCfg.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  assignment.assignmentStatus.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusCfg.fg,
                  ),
                ),
              ),
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
              label: 'Asignado',
              value: dateFmt.format(assignment.assignedAt!.toLocal()),
            ),

          if (assignment.revokedAt != null) ...[
            if (assignment.assignedAt != null) const SizedBox(height: 6),
            _MetaRow(
              icon: HugeIcons.strokeRoundedCalendarRemove01,
              label: 'Revocado',
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
                      fontSize: 12,
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

  _StatusConfig _statusConfig(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.active:
        return _StatusConfig(
          bg: AppColors.secondaryLight,
          fg: AppColors.secondaryDark,
        );
      case AssignmentStatus.revoked:
        return _StatusConfig(
          bg: AppColors.errorLight,
          fg: AppColors.errorDark,
        );
      case AssignmentStatus.pending:
        return _StatusConfig(
          bg: AppColors.accentLight,
          fg: AppColors.accentDark,
        );
    }
  }
}

class _StatusConfig {
  final Color bg;
  final Color fg;

  const _StatusConfig({required this.bg, required this.fg});
}

class _MetaRow extends StatelessWidget {
  final dynamic icon;
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
            fontSize: 12,
            color: c.textTertiary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

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
              icon: HugeIcons.strokeRoundedUserStar01,
              color: c.textTertiary,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin roles asignados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tenés roles asignados en ningún club. '
              'Los administradores pueden asignarte roles desde el panel de administración.',
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorBody({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            SacButton.primary(
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
