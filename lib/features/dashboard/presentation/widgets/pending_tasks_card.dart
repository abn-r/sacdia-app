import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/dashboard_pending.dart';
import '../providers/dashboard_pending_provider.dart';

/// Ruta de la app que atiende cada tipo de pendiente.
String pendingRouteFor(PendingItemType type) => switch (type) {
      PendingItemType.membershipRequests => RouteNames.homeMemberRequests,
      PendingItemType.evidenceFolder => RouteNames.homeEvidences,
      PendingItemType.monthlyReport => RouteNames.homeReports,
      PendingItemType.investitureAuthorizations =>
        RouteNames.investitureAuthorize,
    };

/// Tarjeta «Pendientes» del inicio en modo gestión.
///
/// Lee [dashboardPendingProvider]. Es auxiliar: mientras carga por primera vez,
/// si el endpoint falla o si no hay nada que atender no pinta nada (ni espacio
/// ni error). Cuando se muestra reserva [bottomSpacing] debajo.
class PendingTasksCard extends ConsumerWidget {
  const PendingTasksCard({super.key, this.bottomSpacing = 16});

  final double bottomSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(dashboardPendingProvider).value;
    if (pending == null || pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: PendingTasksPanel(
          pending: pending,
          onItemTap: (item) {
            context.push(pendingRouteFor(item.type));
          }),
    );
  }
}

/// Contenido de la tarjeta, sin dependencia de providers.
///
/// Colapsada por defecto; el estado es local y no se persiste.
class PendingTasksPanel extends StatefulWidget {
  const PendingTasksPanel({
    super.key,
    required this.pending,
    required this.onItemTap,
  });

  final DashboardPending pending;
  final ValueChanged<PendingItem> onItemTap;

  @override
  State<PendingTasksPanel> createState() => _PendingTasksPanelState();
}

class _PendingTasksPanelState extends State<PendingTasksPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pending = widget.pending;
    final reduceMotion = SacMotion.reduceMotionOf(context);
    final toAttend = 'dashboard.pending.to_attend'.plural(pending.total);
    final urgentLabel = pending.urgent > 0
        ? 'dashboard.pending.urgent_count'.plural(pending.urgent)
        : null;

    return SacCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _expanded,
            child: SacPressable(
              semanticLabel: [
                tr('dashboard.pending.title'),
                toAttend,
                if (urgentLabel != null) urgentLabel,
              ].join(', '),
              onTap: () => setState(() => _expanded = !_expanded),
              child: ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        _IconWell(
                          icon: HugeIcons.strokeRoundedTaskDone01,
                          background: c.warningContainer,
                          foreground: c.onWarningContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('dashboard.pending.title'),
                                style: TextStyle(
                                  fontSize: SacFontSize.titleMedium,
                                  fontWeight: FontWeight.w600,
                                  color: c.text,
                                ),
                              ),
                              Text(
                                toAttend,
                                style: TextStyle(
                                  fontSize: SacFontSize.bodySmall,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (urgentLabel != null) ...[
                          const SizedBox(width: 8),
                          SacBadge.error(label: urgentLabel),
                        ],
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration:
                              reduceMotion ? Duration.zero : SacMotion.standard,
                          curve: SacMotion.easeOut,
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowDown01,
                            size: 22,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion ? Duration.zero : SacMotion.standard,
            curve: SacMotion.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < pending.items.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 48,
                            color: c.borderLight,
                          ),
                        _PendingRow(
                          item: pending.items[i],
                          onTap: () => widget.onItemTap(pending.items[i]),
                        ),
                      ],
                      const SizedBox(height: 4),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final HugeIconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS + 2),
      ),
      child: HugeIcon(icon: icon, size: 20, color: foreground),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.item, required this.onTap});

  final PendingItem item;
  final VoidCallback onTap;

  HugeIconData get _icon => switch (item.type) {
        PendingItemType.membershipRequests => HugeIcons.strokeRoundedUserAdd01,
        PendingItemType.evidenceFolder => HugeIcons.strokeRoundedFolder01,
        PendingItemType.monthlyReport => HugeIcons.strokeRoundedFile01,
        PendingItemType.investitureAuthorizations =>
          HugeIcons.strokeRoundedMedal01,
      };

  String get _label => tr('dashboard.pending.${switch (item.type) {
        PendingItemType.membershipRequests => 'membership_requests',
        PendingItemType.evidenceFolder => 'evidence_folder',
        PendingItemType.monthlyReport => 'monthly_report',
        PendingItemType.investitureAuthorizations =>
          'investiture_authorizations',
      }}');

  String? get _subtitle {
    if (item.type != PendingItemType.evidenceFolder) return null;
    final parts = [
      if ((item.rejectedCount ?? 0) > 0)
        'dashboard.pending.rejected_count'.plural(item.rejectedCount!),
      if ((item.notSubmittedCount ?? 0) > 0)
        'dashboard.pending.not_submitted_count'.plural(item.notSubmittedCount!),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String get _badgeText {
    final days = item.daysLeft;
    if (item.type == PendingItemType.monthlyReport && days != null) {
      if (days == 0) return tr('dashboard.pending.due_today');
      if (days > 0) return 'dashboard.pending.due_in_days'.plural(days);
      return 'dashboard.pending.overdue_days'.plural(-days);
    }
    return '${item.count}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final (background, foreground) = switch (item.severity) {
      PendingSeverity.urgent => (c.errorContainer, c.onErrorContainer),
      PendingSeverity.warning => (c.warningContainer, c.onWarningContainer),
      PendingSeverity.info => (c.infoContainer, c.onInfoContainer),
    };
    final badgeText = _badgeText;
    final badge = switch (item.severity) {
      PendingSeverity.urgent => SacBadge.error(label: badgeText),
      PendingSeverity.warning => SacBadge.warning(label: badgeText),
      PendingSeverity.info => SacBadge.info(label: badgeText),
    };
    final subtitle = _subtitle;

    return Semantics(
      button: true,
      label: [_label, if (subtitle != null) subtitle, badgeText].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                _IconWell(
                  icon: _icon,
                  background: background,
                  foreground: foreground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label,
                        style: TextStyle(
                          fontSize: SacFontSize.titleSmall,
                          fontWeight: FontWeight.w500,
                          color: c.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            color: c.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                badge,
                const SizedBox(width: 4),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 20,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
