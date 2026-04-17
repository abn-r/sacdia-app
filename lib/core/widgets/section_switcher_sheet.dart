import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/sac_colors.dart';
import '../utils/role_utils.dart';
import '../../features/auth/domain/entities/authorization_snapshot.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/providers/dashboard_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the custom section-switcher bottom sheet.
///
/// Shared between [ClubInfoCard] and [ClubContextCard]. The sheet manages its
/// own switching state internally, so the caller does not need to hold a
/// loading flag.
Future<void> showSectionSwitcher({
  required BuildContext context,
  required WidgetRef ref,
  required List<AuthorizationGrant> assignments,
  required String? activeAssignmentId,
  required String? userGender,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SectionSwitcherSheet(
      assignments: assignments,
      activeAssignmentId: activeAssignmentId,
      userGender: userGender,
      callerContext: context,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Color helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _sectionColor(String? clubTypeName) {
  if (clubTypeName == null) return AppColors.primary;
  final lower = clubTypeName.toLowerCase();
  if (lower.contains('conquistador')) return AppColors.primary;
  if (lower.contains('aventurer')) return AppColors.sacBlue;
  if (lower.contains('guía') || lower.contains('guia')) return AppColors.secondary;
  return AppColors.primary;
}

/// Returns (badgeBackground, badgeText) per section.
(Color bg, Color fg) _sectionBadgeColors(String? clubTypeName) {
  if (clubTypeName == null) {
    return (AppColors.primaryLight, AppColors.primaryDark);
  }
  final lower = clubTypeName.toLowerCase();
  if (lower.contains('conquistador')) {
    return (AppColors.primaryLight, AppColors.primaryDark);
  }
  if (lower.contains('aventurer')) {
    return (const Color(0xFFE0F0FA), const Color(0xFF1A6B9C));
  }
  if (lower.contains('guía') || lower.contains('guia')) {
    return (AppColors.secondaryLight, AppColors.secondaryDark);
  }
  return (AppColors.primaryLight, AppColors.primaryDark);
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet widget
// ─────────────────────────────────────────────────────────────────────────────

class _SectionSwitcherSheet extends ConsumerStatefulWidget {
  /// The full list of club assignments to display.
  /// Passed in from the caller so the sheet does not need to re-derive it.
  final List<AuthorizationGrant> assignments;

  /// Kept for API compatibility with callers but not used to determine the
  /// active indicator. The sheet now reads the active assignment id directly
  /// from [authNotifierProvider] so it always reflects the live backend state
  /// instead of a value frozen at the moment the sheet was opened.
  final String? activeAssignmentId;

  final String? userGender;

  /// The [BuildContext] of the widget that opened this sheet, used to show
  /// [SnackBar]s on the correct [ScaffoldMessenger] after the sheet closes.
  final BuildContext callerContext;

  const _SectionSwitcherSheet({
    required this.assignments,
    required this.activeAssignmentId,
    required this.userGender,
    required this.callerContext,
  });

  @override
  ConsumerState<_SectionSwitcherSheet> createState() =>
      _SectionSwitcherSheetState();
}

class _SectionSwitcherSheetState extends ConsumerState<_SectionSwitcherSheet> {
  /// The assignmentId currently being switched to (null = not switching).
  String? _switchingId;

  Future<void> _handleSelect(AuthorizationGrant grant) async {
    final id = grant.assignmentId;
    if (id == null) return;

    // Read the live active id at tap time — not the frozen constructor value —
    // so that "already active" detection is always correct.
    final liveActiveId = ref
        .read(authNotifierProvider)
        .valueOrNull
        ?.authorization
        ?.activeAssignmentId;

    // Already active — dismiss with no action.
    if (id == liveActiveId) {
      Navigator.of(context).pop();
      return;
    }

    // Non-active statuses cannot be switched to.
    if (!(grant.isActive)) return;

    setState(() => _switchingId = id);

    // Capture messenger before the async gap to avoid
    // use_build_context_synchronously across async gaps.
    final messenger = ScaffoldMessenger.of(widget.callerContext);

    final success = await ref
        .read(authNotifierProvider.notifier)
        .switchContext(id);

    if (!mounted) return;

    Navigator.of(context).pop();

    if (success) {
      // Explicit invalidation: don't rely on Riverpod's selectAsync detecting
      // the activeAssignmentId change. The reactive chain (state → selector →
      // rebuild) is fragile with Equatable-based AsyncNotifiers. Invalidating
      // directly guarantees the dashboard re-fetches with the new context.
      ref.invalidate(dashboardNotifierProvider);

      messenger.showSnackBar(
        const SnackBar(content: Text('Club cambiado correctamente')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('No se pudo cambiar el club. Intentá de nuevo.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    // Read the live active assignment id directly from the auth provider.
    // This is the source of truth: it matches exactly what the backend returned
    // in authorization.active_assignment.assignment_id via /auth/me, which is
    // also what every other widget (ClubInfoCard, ClubContextCard) consumes.
    // Using the frozen constructor value caused a mismatch when the backend's
    // active context differed from the local snapshot captured at open-time.
    final liveActiveId = ref
        .watch(authNotifierProvider)
        .valueOrNull
        ?.authorization
        ?.activeAssignmentId;

    // Show at most 3 assignments per spec.
    final display = widget.assignments.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Seleccionar sección',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cambiá entre tus clubes asignados',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                ),
              ],
            ),
          ),

          // ── Option cards ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                for (int i = 0; i < display.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _OptionCard(
                    grant: display[i],
                    isActive: display[i].assignmentId == liveActiveId,
                    isSwitching: _switchingId == display[i].assignmentId,
                    userGender: widget.userGender,
                    onTap: _switchingId != null
                        ? null
                        : () => _handleSelect(display[i]),
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom safe area ─────────────────────────────────────
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option card
// ─────────────────────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final AuthorizationGrant grant;
  final bool isActive;
  final bool isSwitching;
  final String? userGender;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.grant,
    required this.isActive,
    required this.isSwitching,
    required this.userGender,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = _sectionColor(grant.clubTypeName);
    final (badgeBg, badgeFg) = _sectionBadgeColors(grant.clubTypeName);
    final roleName = RoleUtils.translate(grant.roleName, gender: userGender);
    final isNonActive = !grant.isActive;

    // Determine card decoration.
    final BoxDecoration decoration;
    if (isActive) {
      decoration = BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1.5,
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    Widget card = Opacity(
      opacity: isNonActive ? 0.6 : 1.0,
      child: Container(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent bar for inactive cards (same as SacCard pattern).
                if (!isActive)
                  Container(width: 4, color: color),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // ── Icon container ──────────────────────────
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedUserGroup,
                              color: color,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // ── Info column ─────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Row 1: club type name
                              Text(
                                grant.clubTypeName ?? 'Club',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              // Row 2: section badge + role text
                              Row(
                                children: [
                                  _SectionBadge(
                                    label: grant.clubTypeName ?? 'Club',
                                    bg: badgeBg,
                                    fg: badgeFg,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      roleName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: c.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isNonActive) ...[
                                    const SizedBox(width: 6),
                                    _StatusLabel(grant: grant),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // ── Trailing: checkmark / spinner ───────────
                        if (isSwitching)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                            ),
                          )
                        else if (isActive)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: color,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Only wrap in InkWell when tappable.
    if (onTap != null && !isNonActive) {
      card = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: card,
        ),
      );
    }

    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section badge pill
// ─────────────────────────────────────────────────────────────────────────────

class _SectionBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _SectionBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline status label for pending/rejected/expired
// ─────────────────────────────────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  final AuthorizationGrant grant;

  const _StatusLabel({required this.grant});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    if (grant.isPending) {
      label = 'Pendiente';
      color = AppColors.accentDark;
    } else if (grant.isRejected) {
      label = 'Rechazado';
      color = AppColors.errorDark;
    } else if (grant.isExpired) {
      label = 'Expirado';
      color = context.sac.textTertiary;
    } else {
      return const SizedBox.shrink();
    }

    return Text(
      '· $label',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }
}
