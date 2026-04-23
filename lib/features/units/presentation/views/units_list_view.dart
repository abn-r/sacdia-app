import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/member_of_month.dart';
import '../../domain/entities/unit.dart';
import '../providers/units_providers.dart';
import 'member_of_month_history_view.dart';
import 'unit_detail_view.dart';
import 'unit_form_sheet.dart';

// ── Role helpers ──────────────────────────────────────────────────────────────

const _kManagementRoles = [
  'director',
  'sub_director',
  'secretario',
  'secretario_tesorero',
];

bool _canManageRole(String? role) {
  if (role == null) return false;
  return _kManagementRoles.contains(role.trim().toLowerCase());
}

bool _canDeleteRole(String? role) {
  return role?.trim().toLowerCase() == 'director';
}

List<Unit> _filterUnitsByRole(
  List<Unit> units,
  String? role,
  String? userId,
) {
  if (role != null && _canManageRole(role)) {
    return units; // management sees all
  }
  // Non-management: only units where the user is directly assigned
  return units.where((u) =>
    u.advisorId == userId ||
    u.substituteAdvisorId == userId ||
    u.captainId == userId ||
    u.secretaryId == userId,
  ).toList();
}

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
    // Auto-navigate when there is exactly ONE visible unit for this user.
    // We wait for the club context so that role-based filtering is applied
    // before deciding, avoiding a race between the async provider and the
    // raw units list.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final rawUnits = ref.read(unitsNotifierProvider).units;
      if (rawUnits.isEmpty) return; // nothing loaded yet — build reacts later

      // Resolve role + userId for filtering (may be cached already)
      final clubCtx = await ref.read(clubContextProvider.future);
      if (!mounted) return;

      final user = ref.read(authNotifierProvider).valueOrNull;
      final role = clubCtx?.roleName;
      final userId = user?.id;

      final visible = _filterUnitsByRole(rawUnits, role, userId);
      if (visible.length == 1) {
        _navigateToUnit(visible.first, replace: true);
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

    // Resolve club context for role-based features (non-blocking — async)
    final clubContextAsync = ref.watch(clubContextProvider);
    final currentUser = ref.watch(authNotifierProvider).valueOrNull;

    final role = clubContextAsync.valueOrNull?.roleName;
    final userId = currentUser?.id;
    final canManage = _canManageRole(role);
    final canDelete = _canDeleteRole(role);

    // Filter units based on role before checking count
    final visibleUnits = _filterUnitsByRole(state.units, role, userId);

    // Caso de una sola unidad: render placeholder mientras se hace el push
    // Use visibleUnits for this check so management roles with 1 unit also
    // navigate directly only when they genuinely have a single unit.
    if (visibleUnits.length == 1 && state.units.isNotEmpty) {
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
      floatingActionButton: canManage
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () {
                // Notifier already calls refresh() internally on success,
                // so the provider state update is automatic. No extra call needed.
                showUnitFormSheet(context: context, ref: ref);
              },
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                size: 26,
                color: Colors.white,
              ),
            )
          : null,
      body: visibleUnits.isEmpty && !state.isLoading
          ? _EmptyState()
          : _Body(
              state: state,
              visibleUnits: visibleUnits,
              canManage: canManage,
              canDelete: canDelete,
              onUnitTap: _navigateToUnit,
              onMemberOfMonthTap: _navigateToMemberOfMonthHistory,
            ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final UnitsState state;

  /// The pre-filtered list of units to display (role-filtered by the parent).
  final List<Unit> visibleUnits;

  final bool canManage;
  final bool canDelete;
  final void Function(Unit unit) onUnitTap;
  final void Function(int clubId, int sectionId) onMemberOfMonthTap;

  const _Body({
    required this.state,
    required this.visibleUnits,
    required this.canManage,
    required this.canDelete,
    required this.onUnitTap,
    required this.onMemberOfMonthTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leer el contexto del club para tener clubId/sectionId
    final clubContextAsync = ref.watch(clubContextProvider);

    return clubContextAsync.when(
      data: (ctx) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount:
            visibleUnits.length + (state.memberOfMonth != null ? 1 : 0),
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
            return _buildUnitCard(context, ref, visibleUnits[unitIndex], unitIndex);
          }
          return _buildUnitCard(context, ref, visibleUnits[index], index);
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: visibleUnits.length,
        itemBuilder: (context, index) =>
            _buildUnitCard(context, ref, visibleUnits[index], index),
      ),
    );
  }

  Widget _buildUnitCard(
    BuildContext context,
    WidgetRef ref,
    Unit unit,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SacCard(
        animate: true,
        animationDelay: Duration(milliseconds: index * 80),
        onTap: () => onUnitTap(unit),
        accentColor: AppColors.primary,
        padding: const EdgeInsets.all(16),
        child: _UnitCard(
          unit: unit,
          canManage: canManage,
          canDelete: canDelete,
          onEdit: canManage
              ? () => showUnitFormSheet(context: context, ref: ref, unit: unit)
              : null,
          onDelete: canDelete
              ? () async {
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Eliminar unidad'),
                          content: Text(
                            '¿Estás seguro de que querés eliminar "${unit.name}"? '
                            'Esta acción no se puede deshacer.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (confirmed) {
                    await ref
                        .read(unitsNotifierProvider.notifier)
                        .deleteUnit(unitId: unit.id);
                  }
                }
              : null,
        ),
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
    final initials = _initials(member.name);
    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: (member.photoUrl != null && member.photoUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: member.photoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 112,
                memCacheHeight: 112,
                placeholder: (_, __) => _MomInitials(initials: initials),
                errorWidget: (_, __, ___) => _MomInitials(initials: initials),
              )
            : _MomInitials(initials: initials),
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
          final initials = _initials(member.name);
          return Positioned(
            left: i * overlap,
            child: ClipOval(
              child: SizedBox(
                width: _size,
                height: _size,
                child: (member.photoUrl != null && member.photoUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: member.photoUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 80,
                        memCacheHeight: 80,
                        placeholder: (_, __) =>
                            _MomInitials(initials: initials, fontSize: 12),
                        errorWidget: (_, __, ___) =>
                            _MomInitials(initials: initials, fontSize: 12),
                      )
                    : _MomInitials(initials: initials, fontSize: 12),
              ),
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

/// Fallback de iniciales con colores de "Miembro del Mes".
class _MomInitials extends StatelessWidget {
  final String initials;
  final double fontSize;

  const _MomInitials({required this.initials, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD4A017).withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFFB8860B),
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

// ── Unit Card ─────────────────────────────────────────────────────────────────

class _UnitCard extends StatelessWidget {
  final Unit unit;
  final bool canManage;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _UnitCard({
    required this.unit,
    this.canManage = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
  });

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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textTertiary,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Trailing: popup menu for management roles, chevron otherwise
        if (canManage)
          PopupMenuButton<_UnitAction>(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedMoreVertical,
              size: 20,
              color: c.textTertiary,
            ),
            onSelected: (action) {
              if (action == _UnitAction.edit) {
                onEdit?.call();
              } else if (action == _UnitAction.delete) {
                onDelete?.call();
              }
            },
            itemBuilder: (_) {
              return <PopupMenuEntry<_UnitAction>>[
                const PopupMenuItem(
                  value: _UnitAction.edit,
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPencilEdit02,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Text('Editar'),
                    ],
                  ),
                ),
                if (canDelete)
                  const PopupMenuItem(
                    value: _UnitAction.delete,
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete02,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Eliminar',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
              ];
            },
          )
        else
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            size: 20,
            color: c.textTertiary,
          ),
      ],
    );
  }
}

/// Discriminated union for the unit card popup actions.
enum _UnitAction { edit, delete }

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
