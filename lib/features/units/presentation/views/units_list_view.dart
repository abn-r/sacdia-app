import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/member_of_month.dart';
import '../../domain/entities/unit.dart';
import '../providers/units_providers.dart';
import 'member_of_month_history_view.dart';
import 'unit_detail_view.dart';

/// Vista de lista de unidades disponibles para el usuario.
///
/// Muestra (en orden):
/// 1. Card "Miembro del Mes" si hay datos para el mes actual.
/// 2. Lista de unidades del usuario.
///
/// Si el usuario tiene exactamente una unidad, navega directamente
/// a [UnitDetailView] sin mostrar la lista (post-build callback).
class UnitsListView extends ConsumerStatefulWidget {
  const UnitsListView({super.key});

  @override
  ConsumerState<UnitsListView> createState() => _UnitsListViewState();
}

class _UnitsListViewState extends ConsumerState<UnitsListView> {
  @override
  void initState() {
    super.initState();

    // Evaluar post-build para no causar un push durante el build tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final units = ref.read(unitsNotifierProvider).units;

      if (units.length == 1) {
        _navigateToUnit(units.first, replace: true);
      }
    });
  }

  void _navigateToUnit(Unit unit, {bool replace = false}) {
    final notifier = ref.read(unitsNotifierProvider.notifier);
    notifier.selectUnit(unit);

    final route = SacSharedAxisRoute<void>(
      builder: (_) => UnitDetailView(unit: unit),
    );

    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _navigateToMemberOfMonthHistory(int clubId, int sectionId) {
    Navigator.of(context).push(
      SacSharedAxisRoute<void>(
        builder: (_) => MemberOfMonthHistoryView(
          clubId: clubId,
          sectionId: sectionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(unitsNotifierProvider);
    final c = context.sac;

    // Caso de una sola unidad: render placeholder mientras se hace el push
    if (state.units.length == 1) {
      return Scaffold(
        backgroundColor: c.background,
        body: const Center(child: SizedBox.shrink()),
      );
    }

    // Necesitamos el clubId/sectionId para navegar al historial
    // Lo obtenemos del provider (asíncrono — usamos una variable local)
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Mis Unidades'),
      ),
      body: state.units.isEmpty && !state.isLoading
          ? _EmptyState()
          : _Body(
              state: state,
              onUnitTap: _navigateToUnit,
              onMemberOfMonthTap: _navigateToMemberOfMonthHistory,
            ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final UnitsState state;
  final void Function(Unit unit) onUnitTap;
  final void Function(int clubId, int sectionId) onMemberOfMonthTap;

  const _Body({
    required this.state,
    required this.onUnitTap,
    required this.onMemberOfMonthTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leer el contexto del club para tener clubId/sectionId
    final clubContextAsync = ref.watch(clubContextProvider);

    return clubContextAsync.when(
      data: (ctx) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: state.units.length + (state.memberOfMonth != null ? 1 : 0),
        itemBuilder: (context, index) {
          // Primer elemento: card de Miembro del Mes (solo si hay datos)
          if (state.memberOfMonth != null) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _MemberOfMonthCard(
                  memberOfMonth: state.memberOfMonth!,
                  onTap: ctx != null
                      ? () => onMemberOfMonthTap(ctx.clubId, ctx.sectionId)
                      : null,
                ),
              );
            }
            // Ajustar índice para la lista de unidades
            final unitIndex = index - 1;
            return _buildUnitCard(context, state.units[unitIndex], unitIndex);
          }
          return _buildUnitCard(context, state.units[index], index);
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: state.units.length,
        itemBuilder: (context, index) =>
            _buildUnitCard(context, state.units[index], index),
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context, Unit unit, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SacCard(
        animate: true,
        animationDelay: Duration(milliseconds: index * 80),
        onTap: () => onUnitTap(unit),
        accentColor: AppColors.primary,
        padding: const EdgeInsets.all(16),
        child: _UnitCard(unit: unit),
      ),
    );
  }
}

// ── Member of Month Card ──────────────────────────────────────────────────────

/// Card que muestra el Miembro del Mes actual.
///
/// No se renderiza si [memberOfMonth] es null (gestionado por el padre).
/// Si hay empate, muestra un stack de avatares con el primer ganador destacado.
class _MemberOfMonthCard extends StatelessWidget {
  final MemberOfMonth memberOfMonth;
  final VoidCallback? onTap;

  const _MemberOfMonthCard({
    required this.memberOfMonth,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final members = memberOfMonth.members;
    final isTie = members.length > 1;
    final primary = members.first;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFD4A017).withValues(alpha: 0.15),
              const Color(0xFFF5C842).withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4A017).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: título + trofeo + mes/año
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAward01,
                  size: 18,
                  color: const Color(0xFFD4A017),
                ),
                const SizedBox(width: 8),
                Text(
                  'Miembro del Mes',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFB8860B),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                ),
                const Spacer(),
                Text(
                  '${memberOfMonth.monthName} ${memberOfMonth.year}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contenido principal: avatar + nombre + puntos
            Row(
              children: [
                // Avatar stack para empates
                if (isTie)
                  _TieAvatarStack(members: members)
                else
                  _SingleAvatar(member: primary),

                const SizedBox(width: 14),

                // Nombres y puntos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTie
                            ? members.map((m) => m.name).join(', ')
                            : primary.name,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w700,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedStar,
                            size: 13,
                            color: const Color(0xFFD4A017),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTie
                                ? '${primary.totalPoints} pts (empate)'
                                : '${primary.totalPoints} pts',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: c.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chevron indicando que se puede navegar al historial
                if (onTap != null)
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleAvatar extends StatelessWidget {
  final MemberOfMonthEntry member;

  const _SingleAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: CachedNetworkImageProvider(member.photoUrl!),
      );
    }
    // Iniciales
    final initials = _initials(member.name);
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFD4A017).withValues(alpha: 0.2),
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFFB8860B),
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _TieAvatarStack extends StatelessWidget {
  final List<MemberOfMonthEntry> members;
  static const double _size = 40;

  const _TieAvatarStack({required this.members});

  @override
  Widget build(BuildContext context) {
    // Mostrar hasta 3 avatares con offset
    final visible = members.take(3).toList();
    const overlap = 20.0;
    final totalWidth = _size + (visible.length - 1) * overlap;

    return SizedBox(
      width: totalWidth,
      height: _size,
      child: Stack(
        children: List.generate(visible.length, (i) {
          final member = visible[i];
          return Positioned(
            left: i * overlap,
            child: CircleAvatar(
              radius: _size / 2,
              backgroundColor: const Color(0xFFD4A017).withValues(alpha: 0.25),
              backgroundImage: (member.photoUrl != null &&
                      member.photoUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(member.photoUrl!)
                  : null,
              child: (member.photoUrl == null || member.photoUrl!.isEmpty)
                  ? Text(
                      _initials(member.name),
                      style: const TextStyle(
                        color: Color(0xFFB8860B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── Unit Card ─────────────────────────────────────────────────────────────────

class _UnitCard extends StatelessWidget {
  final Unit unit;

  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      children: [
        // Icono de unidad
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedUserGroup,
            size: 26,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unit.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _InfoChip(
                    icon: HugeIcons.strokeRoundedLabel,
                    label: unit.type,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: HugeIcons.strokeRoundedUser,
                    label: '${unit.memberCount} miembros',
                  ),
                ],
              ),
              if (unit.leaderName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserStar01,
                      size: 13,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit.leaderName!,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: c.textTertiary,
                              ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Chevron
        HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 20,
          color: c.textTertiary,
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 12, color: c.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: c.textSecondary,
              ),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUserGroup,
            size: 64,
            color: c.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes unidades asignadas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contacta al director de tu club\npara que te asigne una unidad.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}
