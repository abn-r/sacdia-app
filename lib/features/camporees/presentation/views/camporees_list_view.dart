import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_period.dart';

import '../providers/camporees_providers.dart';
import '../widgets/camporee_ticket_parts.dart';
import 'camporee_detail_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

/// Vista de lista de camporees.
///
/// Prioriza patrones móviles nativos: AppBar estándar, tarjetas legibles,
/// targets táctiles amplios y colores semánticos del design system.
class CamporeesListView extends ConsumerWidget {
  const CamporeesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camporeesAsync = ref.watch(camporeesProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;
    final hasHistory = camporeesAsync.maybeWhen(
      data: (camporees) =>
          historicalCamporees(camporees, DateTime.now()).isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'camporees.list.title'.tr(),
          onBack: () => context.go(RouteNames.homeDashboard),
          actions: hasHistory
              ? [
                  _HistoryAction(
                    onTap: () => _openHistory(context),
                  ),
                ]
              : const [],
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: camporeesAsync.when(
              data: (camporees) {
                final current = currentCamporees(camporees, DateTime.now());
                if (current.isEmpty) {
                  return _EmptyCamporeesState(
                    onRetry: () => ref.invalidate(camporeesProvider),
                  );
                }

                return RefreshIndicator(
                  color: SacAccent.of(context).color,
                  onRefresh: () async => ref.invalidate(camporeesProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: SacTopBar.paddingBelowBar(
                        context, EdgeInsets.fromLTRB(hPad, 16, hPad, 28)),
                    itemCount: current.length,
                    itemBuilder: (context, index) {
                      final camporee = current[index];
                      return StaggeredListItem(
                        index: index,
                        initialDelay: const Duration(milliseconds: 40),
                        staggerDelay: SacMotion.stagger,
                        child: _CamporeeCard(
                          camporee: camporee,
                          onTap: () => _openCamporee(context, camporee),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const _CamporeesSkeleton(),
              error: (error, stack) => SacErrorState(
                title: 'camporees.list.error_loading'.tr(),
                message: userErrorMessage(error),
                padding: SacTopBar.paddingBelowBar(
                  context,
                  const EdgeInsets.all(32),
                ),
                onRetry: () => ref.invalidate(camporeesProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _openHistory(BuildContext context) {
  HapticFeedback.selectionClick();
  Navigator.push(
    context,
    SacSharedAxisRoute(
      builder: (context) => const CamporeesHistoryView(),
    ),
  );
}

void _openCamporee(
  BuildContext context,
  Camporee camporee, {
  bool readOnly = false,
}) {
  HapticFeedback.selectionClick();
  Navigator.push(
    context,
    SacSharedAxisRoute(
      builder: (context) => CamporeeDetailView(
        camporeeId: camporee.camporeeId,
        readOnly: readOnly,
      ),
    ),
  );
}

class _HistoryAction extends StatelessWidget {
  final VoidCallback onTap;

  const _HistoryAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SacPressable(
      listenOnly: true,
      child: IconButton(
        enableFeedback: false,
        tooltip: 'camporees.list.history'.tr(),
        onPressed: onTap,
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedClock01,
          size: 22,
          color: SacAccent.of(context).color,
        ),
      ),
    );
  }
}

/// Camporees ya cerrados del mismo alcance. Solo consulta.
class CamporeesHistoryView extends ConsumerWidget {
  const CamporeesHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camporeesAsync = ref.watch(camporeesProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'camporees.list.history_title'.tr(),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: camporeesAsync.when(
              data: (camporees) {
                final history = historicalCamporees(camporees, DateTime.now());
                if (history.isEmpty) {
                  return _EmptyCamporeesState(
                    titleKey: 'camporees.list.history_empty',
                    bodyKey: 'camporees.list.history_empty_body',
                    onRetry: () => ref.invalidate(camporeesProvider),
                  );
                }

                return RefreshIndicator(
                  color: SacAccent.of(context).color,
                  onRefresh: () async => ref.invalidate(camporeesProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: SacTopBar.paddingBelowBar(
                      context,
                      EdgeInsets.fromLTRB(hPad, 16, hPad, 28),
                    ),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final camporee = history[index];
                      return StaggeredListItem(
                        index: index,
                        initialDelay: const Duration(milliseconds: 40),
                        staggerDelay: SacMotion.stagger,
                        child: _CamporeeCard(
                          camporee: camporee,
                          historical: true,
                          onTap: () => _openCamporee(
                            context,
                            camporee,
                            readOnly: true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const _CamporeesSkeleton(),
              error: (error, stack) => SacErrorState(
                title: 'camporees.list.error_loading'.tr(),
                message: userErrorMessage(error),
                padding: SacTopBar.paddingBelowBar(
                  context,
                  const EdgeInsets.all(32),
                ),
                onRetry: () => ref.invalidate(camporeesProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One camporee as an event ticket: who it is for (club logos), name and
/// field, where it stands, then a perforation and the three facts that
/// decide whether to go: dates, place and cost.
class _CamporeeCard extends StatelessWidget {
  final Camporee camporee;
  final VoidCallback onTap;
  final bool historical;

  const _CamporeeCard({
    required this.camporee,
    required this.onTap,
    this.historical = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final status = CamporeeStatus.of(
      context,
      CamporeeTiming.of(camporee, DateTime.now()),
    );
    final cost = camporee.registrationCost;
    final showCost = !historical && cost != null;
    final place = camporee.place.trim();

    return MergeSemantics(
      child: SacCard(
        key: ValueKey('camporee-card-${camporee.camporeeId}'),
        onTap: onTap,
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CamporeeClubLogos(camporee: camporee, dimmed: historical),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camporee.name,
                          style: TextStyle(
                            color: c.text,
                            fontSize: SacFontSize.titleMedium,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (camporee.localFieldName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            camporee.localFieldName!,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: SacFontSize.bodySmall,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        SacBadge(
                          key: ValueKey(
                            'camporee-status-${camporee.camporeeId}',
                          ),
                          label: status.label,
                          variant: status.variant,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 11,
                    child: _TicketFact(
                      icon: HugeIcons.strokeRoundedCalendar03,
                      label: 'camporees.detail.dates'.tr(),
                      value: _shortRange(camporee),
                      sub: _rangeYear(camporee),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 10,
                    child: _TicketFact(
                      icon: HugeIcons.strokeRoundedLocation01,
                      label: 'camporees.detail.place'.tr(),
                      value: place.isEmpty ? '—' : place,
                    ),
                  ),
                  if (showCost) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 8,
                      child: _TicketFact(
                        key: ValueKey('camporee-cost-${camporee.camporeeId}'),
                        icon: HugeIcons.strokeRoundedTicket01,
                        label: 'camporees.detail.cost'.tr(),
                        value: cost == 0
                            ? 'camporees.common.free'.tr()
                            : SacMoney.format(cost),
                        emphasis: true,
                        valueColor: cost == 0 ? c.onSuccessContainer : null,
                        end: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «10–12 feb» within one year; the year goes on its own line.
  static String _shortRange(Camporee camporee) {
    final s = camporee.startDate;
    final e = camporee.endDate;
    if (s.year != e.year) {
      return SacDateFormatter.range(s, e);
    }
    final dayMonth = DateFormat('d MMM');
    if (s.month == e.month) {
      if (s.day == e.day) return dayMonth.format(s);
      return '${s.day}–${dayMonth.format(e)}';
    }
    return '${dayMonth.format(s)} – ${dayMonth.format(e)}';
  }

  static String? _rangeYear(Camporee camporee) =>
      camporee.startDate.year == camporee.endDate.year
          ? '${camporee.startDate.year}'
          : null;
}

/// Dashed line across the card, like the tear line of a ticket.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashPainter(color: context.sac.border),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0.5),
        Offset((x + dash).clamp(0, size.width), 0.5),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// One fact under the perforation: icon and small label, then the value.
class _TicketFact extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final String? sub;
  final bool emphasis;
  final Color? valueColor;
  final bool end;

  const _TicketFact({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.emphasis = false,
    this.valueColor,
    this.end = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final align = end ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 13, color: c.textTertiary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.labelSmall,
                  fontWeight: FontWeight.w500,
                  color: c.textTertiary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: end ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            fontSize:
                emphasis ? SacFontSize.titleMedium : SacFontSize.bodyMedium,
            fontWeight: FontWeight.w700,
            color: valueColor ?? c.text,
            height: 1.25,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (sub != null)
          Text(
            sub!,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              color: c.textSecondary,
              height: 1.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

class _EmptyCamporeesState extends ConsumerWidget {
  final VoidCallback onRetry;
  final String titleKey;
  final String bodyKey;

  const _EmptyCamporeesState({
    required this.onRetry,
    this.titleKey = 'camporees.list.empty',
    this.bodyKey = 'camporees.list.empty_body',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = bodyKey == 'camporees.list.empty_body'
        ? _openCamporeeBody(ref)
        : bodyKey.tr();
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      onRefresh: () async => onRetry(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final top = SacTopBar.frostedInset(context);
          final height =
              (constraints.maxHeight - top).clamp(0.0, double.infinity);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: top),
            children: [
              SizedBox(
                height: height,
                child: SacEmptyState(
                  icon: HugeIcons.strokeRoundedCampfire,
                  title: titleKey.tr(),
                  body: body,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _openCamporeeBody(WidgetRef ref) {
    final name = _firstName(ref.watch(authNotifierProvider).value?.name);
    if (name == null) return 'camporees.list.empty_body_anon'.tr();
    return 'camporees.list.empty_body'.tr(namedArgs: {'name': name});
  }
}

String? _firstName(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final first = trimmed.split(RegExp(r'\s+')).first;
  if (first.length < 2) return null;
  return first;
}

class _CamporeesSkeleton extends StatelessWidget {
  const _CamporeesSkeleton();

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);

    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(
              context, EdgeInsets.fromLTRB(hPad, 16, hPad, 28)),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => const SacSkeletonCard(height: 152),
        ),
      ),
    );
  }
}
