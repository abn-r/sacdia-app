import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';

import '../providers/camporees_providers.dart';
import 'camporee_register_member_view.dart';

/// Vista de miembros inscritos en un camporee.
///
/// Lista completa con badge de estado de seguro. Permite remover miembros
/// con confirmación.
class CamporeeMembersView extends ConsumerWidget {
  final int camporeeId;
  final String camporeeName;

  const CamporeeMembersView({
    super.key,
    required this.camporeeId,
    required this.camporeeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(camporeeMembersProvider(camporeeId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(
          'Miembros inscritos',
          style: TextStyle(color: c.text),
        ),
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CamporeeRegisterMemberView(
                    camporeeId: camporeeId,
                  ),
                ),
              ).then((_) => ref.invalidate(camporeeMembersProvider(camporeeId)));
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedUserAdd01,
              size: 22,
              color: AppColors.primary,
            ),
            tooltip: 'Inscribir miembro',
          ),
        ],
      ),
      body: SafeArea(
        child: membersAsync.when(
          data: (members) {
            if (members.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserGroup,
                      size: 56,
                      color: c.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay miembros inscritos',
                      style: TextStyle(
                        fontSize: 16,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Usá el botón + para inscribir miembros',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SacButton.primary(
                      text: 'Inscribir primer miembro',
                      icon: HugeIcons.strokeRoundedUserAdd01,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CamporeeRegisterMemberView(
                              camporeeId: camporeeId,
                            ),
                          ),
                        ).then((_) =>
                            ref.invalidate(camporeeMembersProvider(camporeeId)));
                      },
                    ),
                  ],
                ),
              );
            }

            final verified = members.where((m) => m.insuranceVerified).length;
            final unverified = members.length - verified;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async =>
                  ref.invalidate(camporeeMembersProvider(camporeeId)),
              child: CustomScrollView(
                slivers: [
                  // Stats summary
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _StatsSummary(
                        total: members.length,
                        verified: verified,
                        unverified: unverified,
                      ),
                    ),
                  ),

                  // Members list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final member = members[index];
                        return StaggeredListItem(
                          index: index,
                          initialDelay: const Duration(milliseconds: 60),
                          staggerDelay: const Duration(milliseconds: 50),
                          child: _MemberTile(
                            member: member,
                            onRemove: () =>
                                _confirmRemove(context, ref, member),
                          ),
                        );
                      },
                      childCount: members.length,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            );
          },
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => Center(
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
                    error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(
                        fontSize: 14, color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SacButton.primary(
                    text: 'Reintentar',
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: () =>
                        ref.invalidate(camporeeMembersProvider(camporeeId)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    CamporeeMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover miembro'),
        content: Text(
          '¿Quieres remover a "${member.userName ?? member.userId}" del camporee?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ref
        .read(camporeeRemoveMemberNotifierProvider(camporeeId).notifier)
        .remove(member.userId);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Miembro "${member.userName ?? member.userId}" removido',
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        final errorMsg = ref
            .read(camporeeRemoveMemberNotifierProvider(camporeeId))
            .errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg ?? 'Error al remover miembro'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}

// ── Stats Summary ──────────────────────────────────────────────────────────────

class _StatsSummary extends StatelessWidget {
  final int total;
  final int verified;
  final int unverified;

  const _StatsSummary({
    required this.total,
    required this.verified,
    required this.unverified,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'Total',
              value: '$total',
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 32, color: c.border,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: _StatChip(
              label: 'Con seguro',
              value: '$verified',
              color: AppColors.secondary,
            ),
          ),
          Container(width: 1, height: 32, color: c.border,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(
            child: _StatChip(
              label: 'Sin seguro',
              value: '$unverified',
              color: unverified > 0 ? AppColors.warning : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.sac.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Member Tile ────────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final CamporeeMember member;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUser,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.userName ?? member.userId,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                if (member.clubName != null && member.clubName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.clubName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    _InsuranceStatusBadge(verified: member.insuranceVerified),
                    if (member.camporeeType != null) ...[
                      const SizedBox(width: 6),
                      _TypeLabel(type: member.camporeeType!),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: onRemove,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedDelete01,
              size: 20,
              color: AppColors.error,
            ),
            tooltip: 'Remover',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.08),
              minimumSize: const Size(36, 36),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insurance Status Badge ─────────────────────────────────────────────────────

class _InsuranceStatusBadge extends StatelessWidget {
  final bool verified;

  const _InsuranceStatusBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.secondary : AppColors.warning;
    final label = verified ? 'Seguro verificado' : 'Sin seguro';
    final icon = verified
        ? HugeIcons.strokeRoundedCheckmarkCircle01
        : HugeIcons.strokeRoundedAlert02;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Type Label ─────────────────────────────────────────────────────────────────

class _TypeLabel extends StatelessWidget {
  final String type;

  const _TypeLabel({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = type == 'union' ? 'Unión' : 'Local';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.sac.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: context.sac.textSecondary,
        ),
      ),
    );
  }
}
