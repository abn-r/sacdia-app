import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

import '../../../../core/auth/club_role_names.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/member_of_month.dart';
import '../../domain/entities/unit.dart';
import '../providers/units_providers.dart';
import 'member_of_month_history_view.dart';
import 'unit_detail_view.dart';
import 'unit_form_sheet.dart';

// ── Role helpers ──────────────────────────────────────────────────────────────

bool _canManageRole(String? role) {
  if (role == null) return false;
  return ClubRoleNames.management.contains(role.trim().toLowerCase());
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
  return units
      .where(
        (u) =>
            u.advisorId == userId ||
            u.substituteAdvisorId == userId ||
            u.captainId == userId ||
            u.secretaryId == userId,
      )
      .toList();
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
    final currentUser =
        ref.watch(authNotifierProvider.select((v) => v.valueOrNull));

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
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('units.list.title'.tr()),
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
      data: (ctx) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _UnitsOverviewHeader(
            count: visibleUnits.length,
            canManage: canManage,
          ),
          const SizedBox(height: 10),
          if (state.memberOfMonth != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemberOfMonthCard(
                memberOfMonth: state.memberOfMonth!,
                onTap: ctx != null
                    ? () => onMemberOfMonthTap(ctx.clubId, ctx.sectionId)
                    : null,
              ),
            ),
          for (final entry in visibleUnits.asMap().entries)
            _buildUnitCard(context, ref, entry.value, entry.key),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _UnitsOverviewHeader(
            count: visibleUnits.length,
            canManage: canManage,
          ),
          const SizedBox(height: 10),
          for (final entry in visibleUnits.asMap().entries)
            _buildUnitCard(context, ref, entry.value, entry.key),
        ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: SacCard(
        animate: true,
        animationDelay: Duration(milliseconds: index * 80),
        onTap: () => onUnitTap(unit),
        padding: EdgeInsets.zero,
        borderColor: context.sac.borderLight,
        child: _UnitCard(
          unit: unit,
          canManage: canManage,
          onActions: canManage
              ? () => _showUnitActionsSheet(context, ref, unit)
              : null,
        ),
      ),
    );
  }

  Future<void> _showUnitActionsSheet(
    BuildContext context,
    WidgetRef ref,
    Unit unit,
  ) async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<_UnitAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnitActionsSheet(unit: unit, canDelete: canDelete),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _UnitAction.edit:
        await showUnitFormSheet(context: context, ref: ref, unit: unit);
        break;
      case _UnitAction.delete:
        await _confirmDeleteUnit(context, ref, unit);
        break;
    }
  }

  Future<void> _confirmDeleteUnit(
    BuildContext context,
    WidgetRef ref,
    Unit unit,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeleteUnitSheet(unit: unit),
    );

    if (!context.mounted || confirmed != true) return;
    HapticFeedback.mediumImpact();
    await ref.read(unitsNotifierProvider.notifier).deleteUnit(unitId: unit.id);
  }
}

// ── Overview Header ──────────────────────────────────────────────────────────

class _UnitsOverviewHeader extends StatelessWidget {
  final int count;
  final bool canManage;

  const _UnitsOverviewHeader({
    required this.count,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.primary.withValues(alpha: 0.06),
          c.surface,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: c.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'units.list.summary_count'.tr(
                    namedArgs: {'count': '$count'},
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  canManage
                      ? 'units.list.summary_manage'.tr()
                      : 'units.list.summary_view'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
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
    // Guard: backend may return an empty members list in edge cases.
    if (members.isEmpty) return const SizedBox.shrink();
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
                  'units.list.member_of_month'.tr(),
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                                ? 'units.list.points_with_tie'.tr(namedArgs: {
                                    'points': '${primary.totalPoints}',
                                  })
                                : 'units.list.points'.tr(namedArgs: {
                                    'points': '${primary.totalPoints}',
                                  }),
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
  final VoidCallback? onActions;

  const _UnitCard({
    required this.unit,
    this.canManage = false,
    this.onActions,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = _unitAccentColor(unit.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _UnitIdentityMark(unit: unit, accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _InfoChip(
                      icon: HugeIcons.strokeRoundedLabel,
                      label: unit.type,
                    ),
                    _InfoChip(
                      icon: HugeIcons.strokeRoundedUser,
                      label: 'units.list.members_count'
                          .tr(namedArgs: {'count': '${unit.memberCount}'}),
                    ),
                  ],
                ),
                if (unit.leaderName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedUserStar01,
                        size: 12,
                        color: c.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'units.list.leader_label'.tr(
                            namedArgs: {'name': unit.leaderName!},
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: c.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canManage)
            Semantics(
              button: true,
              label: 'units.list.manage_unit'.tr(
                namedArgs: {'name': unit.name},
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onActions,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  child: Ink(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    ),
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            accent.withValues(alpha: 0.09),
                            c.surface,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMoreHorizontal,
                          size: 14,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 20,
              color: c.textTertiary,
            ),
        ],
      ),
    );
  }
}

/// Discriminated union for the unit card contextual actions.
enum _UnitAction { edit, delete }

class _UnitIdentityMark extends StatelessWidget {
  final Unit unit;
  final Color accent;

  const _UnitIdentityMark({
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.20),
                accent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          alignment: Alignment.center,
          child: Text(
            _unitInitials(unit.name),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: c.borderLight),
              boxShadow: [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              size: 12,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

Color _unitAccentColor(String type) {
  final lower = type.toLowerCase();
  if (lower.contains('aventurer')) return AppColors.secondary;
  if (lower.contains('guía') || lower.contains('guia')) {
    return AppColors.colorGuiaMayor;
  }
  if (lower.contains('conquistador')) return AppColors.primary;
  return AppColors.primary;
}

String _unitInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '--';

  final initials = words.length >= 2
      ? words.take(2).map((word) => String.fromCharCodes(word.runes.take(1)))
      : [String.fromCharCodes(words.first.runes.take(2))];

  return initials.join().toUpperCase();
}

class _InfoChip extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 11, color: c.textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile Action Sheets ─────────────────────────────────────────────────────

class _UnitActionsSheet extends StatelessWidget {
  final Unit unit;
  final bool canDelete;

  const _UnitActionsSheet({
    required this.unit,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = _unitAccentColor(unit.type);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.textTertiary.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _UnitIdentityMark(unit: unit, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'units.list.action_sheet_title'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ActionSheetTile(
            icon: HugeIcons.strokeRoundedPencilEdit02,
            title: 'units.list.edit_action_title'.tr(),
            subtitle: 'units.list.edit_action_subtitle'.tr(),
            color: accent,
            onTap: () => Navigator.of(context).pop(_UnitAction.edit),
          ),
          if (canDelete) ...[
            const SizedBox(height: 10),
            _ActionSheetTile(
              icon: HugeIcons.strokeRoundedDelete02,
              title: 'units.list.delete_action_title'.tr(),
              subtitle: 'units.list.delete_action_subtitle'.tr(),
              color: c.error,
              destructive: true,
              onTap: () => Navigator.of(context).pop(_UnitAction.delete),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeleteUnitSheet extends StatelessWidget {
  final Unit unit;

  const _DeleteUnitSheet({required this.unit});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.textTertiary.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: c.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedDelete02,
              color: c.error,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'units.list.delete_sheet_title'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'units.list.delete_sheet_body'.tr(namedArgs: {'name': unit.name}),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 22),
          SacButton.destructive(
            text: 'units.list.delete_sheet_confirm'.tr(),
            icon: HugeIcons.strokeRoundedDelete02,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          SacButton(
            text: 'units.list.delete_sheet_cancel'.tr(),
            variant: SacButtonVariant.ghost,
            fullWidth: true,
            textColor: c.textSecondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _ActionSheetTile extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Ink(
            decoration: BoxDecoration(
              color: destructive
                  ? color.withValues(alpha: 0.08)
                  : c.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(
                color:
                    destructive ? color.withValues(alpha: 0.16) : c.borderLight,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: HugeIcon(
                        icon: icon,
                        color: color,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: destructive ? color : c.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: c.textSecondary,
                                      height: 1.35,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 16,
                      color: destructive ? color : c.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
            'units.list.empty_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'units.list.empty_subtitle'.tr(),
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
