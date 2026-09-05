import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_leaderboard.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_description.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_event_agenda.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_location_card.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_leaderboard_panel.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_panel.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_sheet.dart';

import '../providers/camporees_providers.dart';
import 'camporee_members_view.dart';
import 'camporee_register_member_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/views/camporee_order_catalog_view.dart';
import 'package:sacdia_app/features/camporee_supplies/presentation/views/camporee_supply_plan_view.dart';

/// Vista de detalle de un camporee.
///
/// Mantiene navegación y componentes cercanos a patrones nativos: AppBar
/// estándar, contenido en lista vertical y acciones con targets táctiles claros.
class CamporeeDetailView extends ConsumerWidget {
  final int camporeeId;

  const CamporeeDetailView({
    super.key,
    required this.camporeeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(camporeeDetailProvider(camporeeId));

    return detailAsync.when(
      loading: () => const _CamporeeScaffold(body: _DetailSkeleton()),
      error: (error, _) => _CamporeeScaffold(
        body: _ErrorBody(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(camporeeDetailProvider(camporeeId)),
        ),
      ),
      data: (camporee) => _CamporeeScaffold(
        title: camporee.name,
        body: _DetailBody(
          camporee: camporee,
          camporeeId: camporeeId,
        ),
      ),
    );
  }
}

class _CamporeeScaffold extends StatelessWidget {
  final Widget body;
  final String? title;

  const _CamporeeScaffold({required this.body, this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        backgroundColor: c.surfaceVariant,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: SacBackButton(
          color: c.text,
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              context.go(RouteNames.homeDashboard);
            }
          },
        ),
        title: Text(
          title ?? 'camporees.list.title'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

enum _CamporeeDetailTab { info, people, events, agenda }

class _DetailBody extends ConsumerStatefulWidget {
  final Camporee camporee;
  final int camporeeId;

  const _DetailBody({
    required this.camporee,
    required this.camporeeId,
  });

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  _CamporeeDetailTab _tab = _CamporeeDetailTab.info;

  int get _camporeeId => widget.camporeeId;
  Camporee get _camporee => widget.camporee;

  @override
  Widget build(BuildContext context) {
    const eventViewerRoles = {
      ClubRoleNames.director,
      ClubRoleNames.deputyDirector,
      ClubRoleNames.secretary,
      ClubRoleNames.treasurer,
      ClubRoleNames.secretaryTreasurer,
      ClubRoleNames.counselor,
    };
    final authAsync = ref.watch(authNotifierProvider);
    final user = authAsync.valueOrNull;
    final canViewEvents = hasAnyRole(user, eventViewerRoles);
    final registrationAsync =
        ref.watch(camporeeSectionRegistrationProvider(_camporeeId));
    final participantsEnabled =
        camporeeParticipantsAreEnabled(registrationAsync);
    final canRegisterParticipants = canRegisterCamporeeParticipants(
      registrationAsync,
      authAsync,
    );
    final membersAsync = participantsEnabled
        ? ref.watch(camporeeMembersProvider(_camporeeId))
        : const AsyncData<List<CamporeeMember>>(<CamporeeMember>[]);
    final eventsAsync =
        canViewEvents ? ref.watch(camporeeEventsProvider(_camporeeId)) : null;
    final leaderboardAsync = canViewEvents
        ? ref.watch(camporeeLeaderboardProvider(_camporeeId))
        : null;
    final description = _camporee.description?.trim();
    final showDescription = description != null &&
        description.isNotEmpty &&
        !isRedundantCamporeeDescription(_camporee.name, description);

    final tab = !canViewEvents &&
            (_tab == _CamporeeDetailTab.events ||
                _tab == _CamporeeDetailTab.agenda)
        ? _CamporeeDetailTab.info
        : _tab;
    final hPad = Responsive.horizontalPadding(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 4),
          child: _DetailTabBar(
            tab: tab,
            showProgram: canViewEvents,
            onChanged: (next) {
              HapticFeedback.selectionClick();
              setState(() => _tab = next);
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(camporeeDetailProvider(_camporeeId));
              ref.invalidate(camporeeSectionRegistrationProvider(_camporeeId));
              if (participantsEnabled) {
                ref.invalidate(camporeeMembersProvider(_camporeeId));
              }
              if (canViewEvents) {
                ref.invalidate(camporeeEventsProvider(_camporeeId));
                ref.invalidate(camporeeLeaderboardProvider(_camporeeId));
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 48),
              children: _tabChildren(
                tab: tab,
                registrationAsync: registrationAsync,
                membersAsync: membersAsync,
                eventsAsync: eventsAsync,
                leaderboardAsync: leaderboardAsync,
                participantsEnabled: participantsEnabled,
                canRegisterParticipants: canRegisterParticipants,
                showDescription: showDescription,
                description: description,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _tabChildren({
    required _CamporeeDetailTab tab,
    required AsyncValue<CamporeeSectionRegistration> registrationAsync,
    required AsyncValue<List<CamporeeMember>> membersAsync,
    required AsyncValue<List<CamporeeEvent>>? eventsAsync,
    required AsyncValue<CamporeeLeaderboard>? leaderboardAsync,
    required bool participantsEnabled,
    required bool canRegisterParticipants,
    required bool showDescription,
    required String? description,
  }) {
    switch (tab) {
      case _CamporeeDetailTab.info:
        return [
          _TitleSection(camporee: _camporee),
          const SizedBox(height: 24),
          _CamporeeFactsPanel(camporee: _camporee),
          const SizedBox(height: 20),
          CamporeeLocationCard(camporee: _camporee),
          if (showDescription) ...[
            const SizedBox(height: 24),
            _DescriptionSection(description: description!),
          ],
          const SizedBox(height: 24),
          CamporeeSectionRegistrationPanel(
            registrationAsync: registrationAsync,
            onRetry: () => ref.invalidate(
              camporeeSectionRegistrationProvider(_camporeeId),
            ),
            onEnroll: () {
              final registration = registrationAsync.valueOrNull;
              if (registration == null || !registration.canEnroll) return;
              CamporeeSectionRegistrationSheet.show(
                context,
                camporee: _camporee,
                registration: registration,
              );
            },
            onManageParticipants: () => _openParticipants(),
            showParticipantAction: false,
          ),
        ];
      case _CamporeeDetailTab.people:
        return [
          _MembersSection(
            camporeeId: _camporeeId,
            camporeeName: _camporee.name,
            membersAsync: membersAsync,
            participantsEnabled: participantsEnabled,
            canRegisterParticipants: canRegisterParticipants,
            registrationAsync: registrationAsync,
            onRetryMembers: () =>
                ref.invalidate(camporeeMembersProvider(_camporeeId)),
          ),
          if (participantsEnabled) ...[
            const SizedBox(height: 20),
            _ResourcesSection(camporeeId: _camporeeId),
          ],
        ];
      case _CamporeeDetailTab.events:
        return [
          if (eventsAsync != null)
            _EventsSection(
              eventsAsync: eventsAsync,
              scoredOnly: true,
              onRetry: () =>
                  ref.invalidate(camporeeEventsProvider(_camporeeId)),
            ),
          if (leaderboardAsync != null) ...[
            const SizedBox(height: 20),
            CamporeeLeaderboardPanel(
              leaderboardAsync: leaderboardAsync,
              onRetry: () =>
                  ref.invalidate(camporeeLeaderboardProvider(_camporeeId)),
            ),
          ],
        ];
      case _CamporeeDetailTab.agenda:
        return [
          if (eventsAsync != null)
            _AgendaSection(
              eventsAsync: eventsAsync,
              startDate: _camporee.startDate,
              onRetry: () =>
                  ref.invalidate(camporeeEventsProvider(_camporeeId)),
            ),
        ];
    }
  }

  void _openParticipants() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (context) => CamporeeRegisterMemberView(
          camporeeId: _camporeeId,
        ),
      ),
    );
  }
}

class _DetailTabBar extends StatelessWidget {
  final _CamporeeDetailTab tab;
  final bool showProgram;
  final ValueChanged<_CamporeeDetailTab> onChanged;

  const _DetailTabBar({
    required this.tab,
    required this.showProgram,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final tabs = <(_CamporeeDetailTab, String)>[
      (_CamporeeDetailTab.info, 'camporees.detail.tab_info'.tr()),
      (_CamporeeDetailTab.people, 'camporees.detail.tab_people'.tr()),
      if (showProgram) ...[
        (_CamporeeDetailTab.events, 'camporees.detail.tab_events'.tr()),
        (_CamporeeDetailTab.agenda, 'camporees.detail.tab_agenda'.tr()),
      ],
    ];
    final selectedIndex = tabs.indexWhere((entry) => entry.$1 == tab);
    final thumbIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.border,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final thumbWidth = constraints.maxWidth / tabs.length;
            final targetLeft = thumbWidth * thumbIndex;
            return SizedBox(
              height: 44,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: targetLeft),
                duration: reduce ? Duration.zero : SacMotion.press,
                curve: SacMotion.easeOut,
                builder: (context, dx, _) {
                  return Stack(
                    children: [
                      IgnorePointer(
                        child: ExcludeSemantics(
                          child: _DetailTabLabelRow(
                            labels: [for (final entry in tabs) entry.$2],
                            selected: false,
                            compact: tabs.length >= 4,
                          ),
                        ),
                      ),
                      Positioned(
                        key: const Key('camporee-detail-tab-thumb'),
                        left: dx,
                        top: 0,
                        width: thumbWidth,
                        height: 44,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      Positioned(
                        left: dx,
                        top: 0,
                        width: thumbWidth,
                        height: 44,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: constraints.maxWidth,
                                maxWidth: constraints.maxWidth,
                                minHeight: 44,
                                maxHeight: 44,
                                child: Transform.translate(
                                  offset: Offset(-dx, 0),
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    height: 44,
                                    child: _DetailTabLabelRow(
                                      labels: [
                                        for (final entry in tabs) entry.$2
                                      ],
                                      selected: true,
                                      compact: tabs.length >= 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (final entry in tabs)
                            Expanded(
                              child: _DetailTabHitTarget(
                                key: Key(
                                  'camporee-detail-tab-${entry.$1.name}',
                                ),
                                label: entry.$2,
                                selected: tab == entry.$1,
                                onPressed: () => onChanged(entry.$1),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailTabLabelRow extends StatelessWidget {
  final List<String> labels;
  final bool selected;
  final bool compact;

  const _DetailTabLabelRow({
    required this.labels,
    required this.selected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = TextStyle(
      fontSize: compact ? 12 : 14,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      color: selected ? c.onPrimary : c.textSecondary,
      height: 1.1,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );

    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailTabHitTarget extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _DetailTabHitTarget({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: const SizedBox(height: 44),
      ),
    );
  }
}

class _TitleSection extends StatelessWidget {
  final Camporee camporee;

  const _TitleSection({required this.camporee});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconTile(
          icon: HugeIcons.strokeRoundedCampfire,
          color: AppColors.primary,
          size: 56,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                camporee.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 12),
              _ClubTypeBadges(camporee: camporee),
            ],
          ),
        ),
      ],
    );
  }
}

class _CamporeeFactsPanel extends StatelessWidget {
  final Camporee camporee;

  const _CamporeeFactsPanel({required this.camporee});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMMM yyyy', context.locale.toString());
    final currencyFormatter = NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: '\$',
      decimalDigits: 0,
      customPattern: '¤#,##0',
    );
    final dateRange =
        '${dateFormat.format(camporee.startDate)} – ${dateFormat.format(camporee.endDate)}';

    return _SurfacePanel(
      animate: true,
      child: Column(
        children: [
          _FactRow(
            icon: HugeIcons.strokeRoundedCalendar01,
            label: 'camporees.detail.dates'.tr(),
            value: dateRange,
          ),
          _PanelDivider(),
          _FactRow(
            icon: HugeIcons.strokeRoundedMoney01,
            label: 'camporees.detail.cost'.tr(),
            value: _formatCost(camporee.registrationCost, currencyFormatter),
          ),
          if (camporee.localFieldName != null) ...[
            _PanelDivider(),
            _FactRow(
              icon: HugeIcons.strokeRoundedBuilding01,
              label: 'camporees.detail.local_field'.tr(),
              value: camporee.localFieldName!,
            ),
          ],
        ],
      ),
    );
  }

  String _formatCost(double? cost, NumberFormat formatter) {
    if (cost == null || cost == 0) return 'camporees.common.free'.tr();
    return formatter.format(cost);
  }
}

class _DescriptionSection extends StatelessWidget {
  final String description;

  const _DescriptionSection({required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'camporees.detail.description'.tr()),
        const SizedBox(height: 10),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.sac.textSecondary,
                height: 1.6,
              ),
        ),
      ],
    );
  }
}

class _ResourcesSection extends StatelessWidget {
  final int camporeeId;

  const _ResourcesSection({required this.camporeeId});

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'camporees.detail.resources'.tr()),
          const SizedBox(height: 12),
          CamporeeOrdersCta(camporeeId: camporeeId, embedded: true),
          CamporeeSuppliesCta(camporeeId: camporeeId, embedded: true),
        ],
      ),
    );
  }
}

class _EventHonorsSection extends StatelessWidget {
  final List<CamporeeEventHonor> honors;

  const _EventHonorsSection({required this.honors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'camporees.detail.event_honors_title'.tr()),
        const SizedBox(height: 6),
        Text(
          'camporees.detail.event_honors_subtitle'.tr(),
          style: TextStyle(
            color: context.sac.textSecondary,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...honors.map((honor) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EventHonorCard(honor: honor),
            )),
      ],
    );
  }
}

class _EventHonorCard extends StatelessWidget {
  final CamporeeEventHonor honor;

  const _EventHonorCard({required this.honor});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final category = honor.categoryName?.trim();
    final imageUrl = honor.honorImage?.trim();

    return _SurfacePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _honorFallback(c),
                  )
                : _honorFallback(c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  honor.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                ),
                if (category != null && category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (honor.hasMaterial)
                  GestureDetector(
                    onTap: () => SacPdfViewer.show(
                      context,
                      pdfSource: honor.materialUrl!.trim(),
                      title: honor.name,
                    ),
                    child: Text(
                      'camporees.detail.event_honor_open_pdf'.tr(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  Text(
                    'camporees.detail.event_honor_no_pdf'.tr(),
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _honorFallback(SacColors c) {
    return Container(
      width: 48,
      height: 48,
      color: c.surfaceVariant,
      alignment: Alignment.center,
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedAward01,
        color: c.textSecondary,
        size: 22,
      ),
    );
  }
}

class _EventsSection extends StatelessWidget {
  final AsyncValue<List<CamporeeEvent>> eventsAsync;
  final VoidCallback onRetry;
  final bool scoredOnly;

  const _EventsSection({
    required this.eventsAsync,
    required this.onRetry,
    this.scoredOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'camporees.detail.events_title'.tr()),
          const SizedBox(height: 6),
          Text(
            'camporees.detail.events_subtitle'.tr(),
            style: TextStyle(
              color: context.sac.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          eventsAsync.when(
            data: (events) {
              final visible = scoredOnly
                  ? events.where((event) => event.isScored).toList()
                  : events;
              if (visible.isEmpty) {
                return _EmptyInlineState(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  label: scoredOnly
                      ? 'camporees.detail.no_scored_events'.tr()
                      : 'camporees.detail.no_events_yet'.tr(),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < visible.length; index++)
                    StaggeredListItem(
                      index: index,
                      initialDelay: Duration.zero,
                      staggerDelay: SacMotion.stagger,
                      child: _EventTile(
                        key: ValueKey(visible[index].camporeeEventId),
                        event: visible[index],
                      ),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: SacLoading()),
            ),
            error: (_, __) => _InlineRetryState(
              label: 'camporees.detail.events_error'.tr(),
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaSection extends StatelessWidget {
  final AsyncValue<List<CamporeeEvent>> eventsAsync;
  final DateTime startDate;
  final VoidCallback onRetry;

  const _AgendaSection({
    required this.eventsAsync,
    required this.startDate,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;

    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'camporees.detail.agenda_title'.tr()),
          const SizedBox(height: 6),
          Text(
            'camporees.detail.agenda_subtitle'.tr(),
            style: TextStyle(
              color: context.sac.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          eventsAsync.when(
            data: (events) {
              if (events.isEmpty) {
                return _EmptyInlineState(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  label: 'camporees.detail.agenda_empty'.tr(),
                );
              }

              final entries = buildCamporeeAgendaEntries(events);
              final visible = [
                for (final entry in entries)
                  if (entry.event.agendaVisible) entry,
              ];
              final pending = [
                for (final entry in entries)
                  if (!entry.event.agendaVisible) entry,
              ];
              final groups = groupCamporeeAgendaByDay(visible);
              var index = 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in groups) ...[
                    _AgendaDayHeader(
                      dayNumber: group.$1,
                      calendarDate: camporeeAgendaDayDate(startDate, group.$1),
                      locale: locale,
                    ),
                    for (final entry in group.$2)
                      StaggeredListItem(
                        index: index++,
                        initialDelay: Duration.zero,
                        staggerDelay: SacMotion.stagger,
                        child: _AgendaRow(
                          entry: entry,
                          showSchedule: true,
                        ),
                      ),
                  ],
                  if (pending.isNotEmpty) ...[
                    if (visible.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 10),
                        child: Text(
                          'camporees.detail.agenda_pending'.tr(),
                          style: TextStyle(
                            color: context.sac.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    for (final entry in pending)
                      StaggeredListItem(
                        index: index++,
                        initialDelay: Duration.zero,
                        staggerDelay: SacMotion.stagger,
                        child: _AgendaRow(
                          entry: entry,
                          showSchedule: false,
                        ),
                      ),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: SacLoading()),
            ),
            error: (_, __) => _InlineRetryState(
              label: 'camporees.detail.events_error'.tr(),
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaDayHeader extends StatelessWidget {
  final int dayNumber;
  final DateTime calendarDate;
  final String locale;

  const _AgendaDayHeader({
    required this.dayNumber,
    required this.calendarDate,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateLabel = SacDateFormatter.formatCalendar(
      calendarDate,
      'EEE d MMM',
      locale: locale,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'camporees.detail.event_day'.tr(
              namedArgs: {'day': '$dayNumber'},
            ),
            style: TextStyle(
              color: c.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dateLabel,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final CamporeeAgendaEntry entry;
  final bool showSchedule;

  const _AgendaRow({
    required this.entry,
    required this.showSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final event = entry.event;
    final clock = showSchedule
        ? (formatCamporeeClock(entry.startsAt) ?? '—')
        : 'camporees.detail.agenda_pending'.tr();
    final typeLabel = _eventTypeLabel(event);
    final venue = showSchedule ? entry.venueName?.trim() : null;
    final metaParts = [
      if (typeLabel.isNotEmpty) typeLabel,
      if (venue != null && venue.isNotEmpty) venue,
    ];

    return Container(
      key: Key(
        'camporee-agenda-${event.camporeeEventId}-${entry.dayNumber}-${entry.startsAt ?? 'none'}',
      ),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openCamporeeEvent(context, event),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    clock,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _IconTile(
                  icon: _eventCategoryIcon(event.displayCategory),
                  color: _eventCategoryColor(context, event.displayCategory),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CamporeeEvent event;

  const _EventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pointsLabel = 'camporees.detail.event_points'
        .tr(namedArgs: {'points': '${event.maxPoints}'});

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openCamporeeEvent(context, event),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _IconTile(
                  icon: _eventCategoryIcon(event.displayCategory),
                  color: _eventCategoryColor(context, event.displayCategory),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  pointsLabel,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CamporeeEventDetailPage extends StatelessWidget {
  final CamporeeEvent event;

  const _CamporeeEventDetailPage({required this.event});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final description = event.description?.trim();
    final hasSchedules = event.agendaVisible && event.scheduleBlocks.isNotEmpty;
    final hasStaffSummary = event.agendaVisible &&
        (event.responsibleDisplayNames.isNotEmpty ||
            event.supportingDisplayNames.isNotEmpty);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: SacBackButton(
          color: c.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'camporees.detail.event_detail_title'.tr(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            _EventDetailHeader(event: event),
            const SizedBox(height: 18),
            _EventFactsPanel(event: event),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DescriptionSection(description: description),
            ],
            if (event.honors.isNotEmpty) ...[
              const SizedBox(height: 24),
              _EventHonorsSection(honors: event.honors),
            ],
            if (hasStaffSummary) ...[
              const SizedBox(height: 24),
              _EventStaffDetail(event: event),
            ],
            if (hasSchedules) ...[
              const SizedBox(height: 24),
              _SectionHeader(label: 'camporees.detail.event_schedules'.tr()),
              const SizedBox(height: 10),
              _ScheduleBlocksPreview(blocks: event.scheduleBlocks),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventDetailHeader extends StatelessWidget {
  final CamporeeEvent event;

  const _EventDetailHeader({required this.event});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconTile(
          icon: _eventCategoryIcon(event.displayCategory),
          color: _eventCategoryColor(context, event.displayCategory),
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            event.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  height: 1.15,
                ),
          ),
        ),
      ],
    );
  }
}

class _EventFactsPanel extends StatelessWidget {
  final CamporeeEvent event;

  const _EventFactsPanel({required this.event});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    void addFact({
      required HugeIconData icon,
      required String label,
      required String value,
    }) {
      if (rows.isNotEmpty) rows.add(_PanelDivider());
      rows.add(_FactRow(icon: icon, label: label, value: value));
    }

    final eventTypeName = event.eventTypeName?.trim();
    if (eventTypeName != null && eventTypeName.isNotEmpty) {
      addFact(
        icon: HugeIcons.strokeRoundedTag01,
        label: 'camporees.detail.event_type'.tr(),
        value: eventTypeName,
      );
    }

    if (event.agendaVisible) {
      addFact(
        icon: HugeIcons.strokeRoundedCalendar01,
        label: 'camporees.detail.event_day_label'.tr(),
        value: 'camporees.detail.event_day'
            .tr(namedArgs: {'day': '${event.dayNumber}'}),
      );

      final timeLabel = _eventTimeLabel(event);
      if (timeLabel != null) {
        addFact(
          icon: HugeIcons.strokeRoundedClock01,
          label: 'camporees.detail.event_time'.tr(),
          value: timeLabel,
        );
      }
    } else {
      addFact(
        icon: HugeIcons.strokeRoundedLockKey,
        label: 'camporees.detail.event_schedule'.tr(),
        value: 'camporees.detail.agenda_pending'.tr(),
      );
    }

    addFact(
      icon: HugeIcons.strokeRoundedAward01,
      label: 'camporees.detail.event_total_points'.tr(),
      value: 'camporees.detail.event_points'
          .tr(namedArgs: {'points': '${event.maxPoints}'}),
    );

    final venueName = event.venueName?.trim();
    if (event.agendaVisible && venueName != null && venueName.isNotEmpty) {
      addFact(
        icon: HugeIcons.strokeRoundedLocation01,
        label: 'camporees.detail.place'.tr(),
        value: venueName,
      );
    }

    return _SurfacePanel(child: Column(children: rows));
  }
}

class _EventStaffDetail extends StatelessWidget {
  final CamporeeEvent event;

  const _EventStaffDetail({required this.event});

  @override
  Widget build(BuildContext context) {
    final responsibleNames = event.responsibleDisplayNames.join(', ');
    final supportingNames = event.supportingDisplayNames.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'camporees.detail.event_staff_title'.tr()),
        const SizedBox(height: 10),
        _SurfacePanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (responsibleNames.isNotEmpty)
                _MiniMeta(
                  icon: HugeIcons.strokeRoundedUserCheck01,
                  label: 'camporees.detail.event_staff_responsible'.tr(
                    namedArgs: {'names': responsibleNames},
                  ),
                ),
              if (supportingNames.isNotEmpty)
                _MiniMeta(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  label: 'camporees.detail.event_staff_supporting'.tr(
                    namedArgs: {'names': supportingNames},
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String? _eventTimeLabel(CamporeeEvent event) {
  if (event.startsAt == null || event.startsAt!.trim().isEmpty) return null;
  if (event.endsAt == null || event.endsAt!.trim().isEmpty) {
    return event.startsAt;
  }
  return '${event.startsAt} – ${event.endsAt}';
}

String _eventTypeLabel(CamporeeEvent event) {
  final name = event.eventTypeName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return event.displayCategory;
}

void _openCamporeeEvent(BuildContext context, CamporeeEvent event) {
  HapticFeedback.selectionClick();
  Navigator.push(
    context,
    SacSharedAxisRoute(
      builder: (_) => _CamporeeEventDetailPage(event: event),
    ),
  );
}

HugeIconData _eventCategoryIcon(String category) {
  switch (category) {
    case 'espiritual':
      return HugeIcons.strokeRoundedBookOpen01;
    case 'competencia':
      return HugeIcons.strokeRoundedChampion;
    case 'taller':
      return HugeIcons.strokeRoundedTools;
    case 'ceremonial':
      return HugeIcons.strokeRoundedFlag01;
    case 'social':
      return HugeIcons.strokeRoundedUserGroup;
    default:
      return HugeIcons.strokeRoundedCalendar03;
  }
}

Color _eventCategoryColor(BuildContext context, String category) {
  switch (category) {
    case 'espiritual':
      return AppColors.secondary;
    case 'competencia':
      return AppColors.primary;
    case 'taller':
      return context.sac.info;
    case 'ceremonial':
      return context.sac.warning;
    case 'social':
      return context.sac.success;
    default:
      return context.sac.textTertiary;
  }
}

class _ScheduleBlocksPreview extends StatelessWidget {
  final List<CamporeeEventScheduleBlock> blocks;

  const _ScheduleBlocksPreview({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      children: [
        for (final block in blocks)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title?.trim().isNotEmpty == true
                      ? block.title!.trim()
                      : 'camporees.detail.schedule_block'.tr(),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniMeta(
                      icon: HugeIcons.strokeRoundedCalendar01,
                      label: 'camporees.detail.event_day'
                          .tr(namedArgs: {'day': '${block.dayNumber}'}),
                    ),
                    if (_blockTime(block) != null)
                      _MiniMeta(
                        icon: HugeIcons.strokeRoundedClock01,
                        label: _blockTime(block)!,
                      ),
                    if (block.venueName != null)
                      _MiniMeta(
                        icon: HugeIcons.strokeRoundedLocation01,
                        label: block.venueName!,
                      ),
                  ],
                ),
                if (block.assignedSectionNames.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    block.assignedSectionNames.join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static String? _blockTime(CamporeeEventScheduleBlock block) {
    if (block.startsAt == null || block.startsAt!.trim().isEmpty) return null;
    if (block.endsAt == null || block.endsAt!.trim().isEmpty) {
      return block.startsAt;
    }
    return '${block.startsAt} – ${block.endsAt}';
  }
}

class _MiniMeta extends StatelessWidget {
  final HugeIconData icon;
  final String label;

  const _MiniMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 12, color: c.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MembersSection extends StatelessWidget {
  final int camporeeId;
  final String camporeeName;
  final AsyncValue<List<CamporeeMember>> membersAsync;
  final bool participantsEnabled;
  final bool canRegisterParticipants;
  final AsyncValue<CamporeeSectionRegistration> registrationAsync;
  final VoidCallback onRetryMembers;

  const _MembersSection({
    required this.camporeeId,
    required this.camporeeName,
    required this.membersAsync,
    required this.participantsEnabled,
    required this.canRegisterParticipants,
    required this.registrationAsync,
    required this.onRetryMembers,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'camporees.detail.members_enrolled'.tr()),
          const SizedBox(height: 14),
          if (!participantsEnabled)
            _ParticipantsLockedState(registrationAsync: registrationAsync)
          else
            membersAsync.when(
              data: (members) => _MembersPreview(
                camporeeId: camporeeId,
                camporeeName: camporeeName,
                members: members,
              ),
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Semantics(
                    label: 'camporees.detail.members_loading'.tr(),
                    liveRegion: true,
                    child: const SacLoading(),
                  ),
                ),
              ),
              error: (_, __) => _MembersError(onRetry: onRetryMembers),
            ),
          if (canRegisterParticipants) ...[
            const SizedBox(height: 14),
            SacButton.primary(
              text: 'camporees.section_registration.participants_action'.tr(),
              icon: HugeIcons.strokeRoundedUserAdd01,
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  SacSharedAxisRoute(
                    builder: (context) => CamporeeRegisterMemberView(
                      camporeeId: camporeeId,
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              textColor: AppColors.inkOnBrand,
              labelMaxLines: 2,
              labelOverflow: TextOverflow.visible,
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersError extends StatelessWidget {
  final VoidCallback onRetry;

  const _MembersError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'camporees.detail.members_error'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sac.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'camporees.detail.retry_members_semantics'.tr(),
            child: SacButton.outline(
              text: 'camporees.detail.retry_members'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
              textColor: context.sac.text,
              borderColor: context.sac.textSecondary,
              labelMaxLines: 2,
              labelOverflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsLockedState extends StatelessWidget {
  final AsyncValue<CamporeeSectionRegistration> registrationAsync;

  const _ParticipantsLockedState({required this.registrationAsync});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: registrationAsync.isLoading || registrationAsync.hasError,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.sac.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedLockKey,
              size: 20,
              color: context.sac.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'camporees.section_registration.participants_locked'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.sac.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersPreview extends StatelessWidget {
  final int camporeeId;
  final String camporeeName;
  final List<CamporeeMember> members;

  const _MembersPreview({
    required this.camporeeId,
    required this.camporeeName,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (members.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.borderLight),
        ),
        child: Text(
          'camporees.detail.no_members_yet'.tr(),
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: c.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final preview = members.take(3).toList();
    return Column(
      children: [
        for (var index = 0; index < preview.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          StaggeredListItem(
            index: index,
            initialDelay: Duration.zero,
            staggerDelay: SacMotion.stagger,
            child: _MemberPreviewTile(member: preview[index]),
          ),
        ],
        const SizedBox(height: 12),
        SacButton.outline(
          text: 'camporees.detail.view_all_members'
              .tr(namedArgs: {'count': '${members.length}'}),
          icon: HugeIcons.strokeRoundedUserGroup,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              SacSharedAxisRoute(
                builder: (context) => CamporeeMembersView(
                  camporeeId: camporeeId,
                  camporeeName: camporeeName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  final HugeIconData icon;
  final String label;

  const _EmptyInlineState({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderLight),
      ),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 18, color: c.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineRetryState extends StatelessWidget {
  final String label;
  final VoidCallback onRetry;

  const _InlineRetryState({
    required this.label,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 18,
            color: c.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }
}

class _MemberPreviewTile extends StatelessWidget {
  final CamporeeMember member;

  const _MemberPreviewTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _MemberAvatar(member: member),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.userName ?? member.userId,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (member.clubName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.clubName!,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _InsuranceMark(verified: member.insuranceVerified),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;

  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: HugeIcon(icon: icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _PanelDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: context.sac.divider);
  }
}

class _MemberAvatar extends StatelessWidget {
  final CamporeeMember member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    final imageUrl = member.userImageUrl;

    return ClipOval(
      child: Container(
        width: 44,
        height: 44,
        color: AppColors.primary.withValues(alpha: 0.10),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _AvatarFallback(),
              )
            : const _AvatarFallback(),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedUser,
        size: 20,
        color: AppColors.primary,
      ),
    );
  }
}

class _InsuranceMark extends StatelessWidget {
  final bool verified;

  const _InsuranceMark({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? context.sac.success : context.sac.error;
    final label = verified
        ? 'camporees.detail.insurance_ok'.tr()
        : 'camporees.detail.no_insurance'.tr();

    return Semantics(
      label: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: HugeIcon(
            icon: verified
                ? HugeIcons.strokeRoundedCheckmarkCircle01
                : HugeIcons.strokeRoundedAlert02,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ClubTypeBadges extends StatelessWidget {
  final Camporee camporee;

  const _ClubTypeBadges({required this.camporee});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (camporee.includesAdventurers)
        _Badge(
          label: 'camporees.common.adventurers'.tr(),
          color: context.sac.warning,
        ),
      if (camporee.includesPathfinders)
        _Badge(
          label: 'camporees.common.pathfinders'.tr(),
          color: AppColors.primary,
        ),
      if (camporee.includesMasterGuides)
        _Badge(
          label: 'camporees.common.master_guides'.tr(),
          color: context.sac.success,
        ),
    ];

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.sac.text,
          ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final HugeIconData icon;
  final Color color;
  final double size;

  const _IconTile({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size >= 50 ? 18 : 14),
      ),
      child: Center(
        child: HugeIcon(icon: icon, size: size * 0.48, color: color),
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  final Widget child;
  final bool animate;
  final EdgeInsetsGeometry padding;

  const _SurfacePanel({
    required this.child,
    this.animate = false,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return SacCard(
      animate: animate,
      padding: padding,
      child: child,
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Responsive.horizontalPadding(context),
        24,
        Responsive.horizontalPadding(context),
        48,
      ),
      children: [
        Container(
          height: 88,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconTile(
              icon: HugeIcons.strokeRoundedAlert02,
              color: c.error,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              'camporees.detail.error_loading'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
