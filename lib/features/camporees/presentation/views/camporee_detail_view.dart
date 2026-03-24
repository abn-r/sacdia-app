import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';

import '../providers/camporees_providers.dart';
import 'camporee_members_view.dart';
import 'camporee_register_member_view.dart';

/// Vista de detalle de un camporee.
///
/// Muestra información completa del camporee y la sección de miembros inscritos.
class CamporeeDetailView extends ConsumerWidget {
  final int camporeeId;

  const CamporeeDetailView({
    super.key,
    required this.camporeeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(camporeeDetailProvider(camporeeId));

    return Scaffold(
      backgroundColor: context.sac.background,
      body: detailAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _ErrorBody(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(camporeeDetailProvider(camporeeId)),
        ),
        data: (camporee) => _DetailBody(
          camporee: camporee,
          camporeeId: camporeeId,
        ),
      ),
    );
  }
}

// ── Detail Body ───────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final Camporee camporee;
  final int camporeeId;

  const _DetailBody({
    required this.camporee,
    required this.camporeeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(camporeeMembersProvider(camporeeId));
    final c = context.sac;
    final dateFormat = DateFormat('d MMMM yyyy', 'es');

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Hero header
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedAward01,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        camporee.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Info card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Descripción
                if (camporee.description != null &&
                    camporee.description!.isNotEmpty) ...[
                  _SectionTitle(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    label: 'Descripción',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    camporee.description!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Info grid
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: HugeIcons.strokeRoundedCalendar01,
                        label: 'Inicio',
                        value: dateFormat.format(camporee.startDate),
                      ),
                      Divider(color: c.border, height: 20),
                      _DetailRow(
                        icon: HugeIcons.strokeRoundedCalendar02,
                        label: 'Fin',
                        value: dateFormat.format(camporee.endDate),
                      ),
                      Divider(color: c.border, height: 20),
                      _DetailRow(
                        icon: HugeIcons.strokeRoundedLocation01,
                        label: 'Lugar',
                        value: camporee.place,
                      ),
                      if (camporee.registrationCost != null) ...[
                        Divider(color: c.border, height: 20),
                        _DetailRow(
                          icon: HugeIcons.strokeRoundedMoney01,
                          label: 'Costo',
                          value: camporee.registrationCost == 0
                              ? 'Gratuito'
                              : NumberFormat.currency(
                                  locale: 'es',
                                  symbol: '\$',
                                  decimalDigits: 0,
                                ).format(camporee.registrationCost),
                        ),
                      ],
                      if (camporee.localFieldName != null) ...[
                        Divider(color: c.border, height: 20),
                        _DetailRow(
                          icon: HugeIcons.strokeRoundedBuilding01,
                          label: 'Campo local',
                          value: camporee.localFieldName!,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Club type badges
                _SectionTitle(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  label: 'Tipos de club',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (camporee.includesAdventurers)
                      _TypeChip(
                          label: 'Aventureros',
                          color: AppColors.warning),
                    if (camporee.includesPathfinders)
                      _TypeChip(
                          label: 'Conquistadores',
                          color: AppColors.primary),
                    if (camporee.includesMasterGuides)
                      _TypeChip(
                          label: 'Guías Mayores',
                          color: AppColors.secondary),
                  ],
                ),

                const SizedBox(height: 28),
                Divider(color: c.border),
                const SizedBox(height: 16),

                // Miembros inscritos header
                Row(
                  children: [
                    _SectionTitle(
                      icon: HugeIcons.strokeRoundedUserGroup,
                      label: 'Miembros inscritos',
                    ),
                    const Spacer(),
                    // Botón para inscribir miembro
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CamporeeRegisterMemberView(
                              camporeeId: camporeeId,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedUserAdd01,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Inscribir',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Members preview (first 3)
        membersAsync.when(
          data: (members) {
            if (members.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Aún no hay miembros inscritos.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.sac.textSecondary,
                    ),
                  ),
                ),
              );
            }

            final preview = members.take(3).toList();
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return StaggeredListItem(
                    index: index,
                    child: _MemberPreviewTile(member: preview[index]),
                  );
                },
                childCount: preview.length,
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: SacLoading()),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // "Ver todos" button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: membersAsync.maybeWhen(
              data: (members) => members.isNotEmpty
                  ? SacButton.outline(
                      text: 'Ver todos los miembros (${members.length})',
                      icon: HugeIcons.strokeRoundedUserGroup,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CamporeeMembersView(
                              camporeeId: camporeeId,
                              camporeeName: camporee.name,
                            ),
                          ),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Detail Row ─────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(icon: icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: c.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: c.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Type Chip ──────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Member Preview Tile ────────────────────────────────────────────────────────

class _MemberPreviewTile extends StatelessWidget {
  final CamporeeMember member;

  const _MemberPreviewTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUser,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.userName ?? member.userId,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
          _InsuranceBadge(verified: member.insuranceVerified),
        ],
      ),
    );
  }
}

// ── Insurance Badge ────────────────────────────────────────────────────────────

class _InsuranceBadge extends StatelessWidget {
  final bool verified;

  const _InsuranceBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.secondary : AppColors.error;
    final label = verified ? 'Seguro OK' : 'Sin seguro';

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
          HugeIcon(
            icon: verified
                ? HugeIcons.strokeRoundedCheckmarkCircle01
                : HugeIcons.strokeRoundedAlert02,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
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

// ── Section Title ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final dynamic icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
        ),
      ],
    );
  }
}

// ── Error Body ─────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
              'Error al cargar el camporee',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                  fontSize: 14, color: context.sac.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
