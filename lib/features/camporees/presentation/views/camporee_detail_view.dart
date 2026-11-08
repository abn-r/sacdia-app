import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_leaderboard.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_score_breakdown.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_description.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_period.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_event_agenda.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_map_options_sheet.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_map_preview.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_ticket_parts.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_event_scores_group.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_agenda_now_group.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_leaderboard_panel.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_panel.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_sheet.dart';

import '../providers/camporees_providers.dart';
import 'camporee_members_view.dart';
import 'camporee_register_member_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/widgets/payment_order_widgets.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/views/camporee_order_catalog_view.dart';
import 'package:sacdia_app/features/camporee_supplies/presentation/views/camporee_supply_plan_view.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

/// Vista de detalle de un camporee.
///
/// Mantiene navegación y componentes cercanos a patrones nativos: AppBar
/// estándar, contenido en lista vertical y acciones con targets táctiles claros.
class CamporeeDetailView extends ConsumerWidget {
  final int camporeeId;

  /// Consulta. El detalle también se bloquea si la fecha de cierre ya pasó.
  final bool readOnly;

  const CamporeeDetailView({
    super.key,
    required this.camporeeId,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(camporeeDetailProvider(camporeeId));

    return detailAsync.when(
      loading: () => const _CamporeeScaffold(body: _DetailSkeleton()),
      error: (error, _) => _CamporeeScaffold(
        body: Builder(
          builder: (context) => SacErrorState(
            title: 'camporees.detail.error_loading'.tr(),
            message: userErrorMessage(error),
            padding: SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.all(32),
            ),
            onRetry: () => ref.invalidate(camporeeDetailProvider(camporeeId)),
          ),
        ),
      ),
      data: (camporee) => _CamporeeScaffold(
        title: 'camporees.detail.bar_title'.tr(),
        body: _DetailBody(
          camporee: camporee,
          camporeeId: camporeeId,
          readOnly: readOnly || !camporeeIsOpen(camporee, DateTime.now()),
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
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: title ?? 'camporees.list.title'.tr(),
          backgroundColor: c.background,
          onBack: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              context.go(RouteNames.homeDashboard);
            }
          },
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(top: false, child: body),
        ),
      ),
    );
  }
}

enum _CamporeeDetailTab { info, people, events, agenda }

class _DetailBody extends ConsumerStatefulWidget {
  final Camporee camporee;
  final int camporeeId;
  final bool readOnly;

  const _DetailBody({
    required this.camporee,
    required this.camporeeId,
    required this.readOnly,
  });

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  _CamporeeDetailTab _tab = _CamporeeDetailTab.info;
  int _tabSlide = 1;

  int get _camporeeId => widget.camporeeId;

  void _selectTab(_CamporeeDetailTab next) {
    if (next == _tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tabSlide = next.index >= _tab.index ? 1 : -1;
      _tab = next;
    });
  }

  Camporee get _camporee => widget.camporee;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authNotifierProvider);
    final user = authAsync.value;
    final canViewEvents = hasCapability(user, 'club.operational_staff');
    final registrationAsync =
        ref.watch(camporeeSectionRegistrationProvider(_camporeeId));
    final participantsEnabled =
        camporeeParticipantsAreEnabled(registrationAsync);
    final canRegisterParticipants = !widget.readOnly &&
        canRegisterCamporeeParticipants(
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
    // Only the events list reads it; a failure there must not break the tab.
    final scoreBreakdown = canViewEvents
        ? ref.watch(camporeeScoreBreakdownProvider(_camporeeId)).value
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
    final registration = registrationAsync.value;
    final showEnrollBar = tab == _CamporeeDetailTab.info &&
        !widget.readOnly &&
        registration != null &&
        registration.canEnroll &&
        registration.status == CamporeeSectionRegistrationStatus.notEnrolled;
    final showParticipantsBar =
        tab == _CamporeeDetailTab.people && canRegisterParticipants;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            hPad,
            SacTopBar.frostedInset(context) + 8,
            hPad,
            4,
          ),
          child: _DetailTabBar(
            tab: tab,
            showProgram: canViewEvents,
            onChanged: _selectTab,
          ),
        ),
        Expanded(
          child: _DetailTabBody(
            tab: tab,
            slide: _tabSlide,
            child: RefreshIndicator(
              color: SacAccent.of(context).color,
              onRefresh: () async {
                ref.invalidate(camporeeDetailProvider(_camporeeId));
                ref.invalidate(
                    camporeeSectionRegistrationProvider(_camporeeId));
                if (participantsEnabled) {
                  ref.invalidate(camporeeMembersProvider(_camporeeId));
                  ref.invalidate(paymentOrdersListProvider);
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
                  scoreBreakdown: scoreBreakdown,
                  participantsEnabled: participantsEnabled,
                  canRegisterParticipants: canRegisterParticipants,
                  readOnly: widget.readOnly,
                  showDescription: showDescription,
                  description: description,
                ),
              ),
            ),
          ),
        ),
        if (showEnrollBar)
          _PinnedAction(
            key: const Key('camporee-enroll-bar'),
            text: 'camporees.section_registration.enroll_action'.tr(),
            icon: HugeIcons.strokeRoundedEdit02,
            onPressed: () => CamporeeSectionRegistrationSheet.show(
              context,
              camporee: _camporee,
              registration: registration,
            ),
          )
        else if (showParticipantsBar)
          _PinnedAction(
            key: const Key('camporee-participants-bar'),
            text: 'camporees.section_registration.participants_action'.tr(),
            icon: HugeIcons.strokeRoundedUserAdd01,
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                SacSharedAxisRoute(
                  builder: (context) =>
                      CamporeeRegisterMemberView(camporeeId: _camporeeId),
                ),
              );
            },
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
    required CamporeeScoreBreakdown? scoreBreakdown,
    required bool participantsEnabled,
    required bool canRegisterParticipants,
    required bool readOnly,
    required bool showDescription,
    required String? description,
  }) {
    switch (tab) {
      case _CamporeeDetailTab.info:
        return [
          _DetailHeader(camporee: _camporee, readOnly: readOnly),
          const SizedBox(height: 24),
          if (eventsAsync?.value case final events?)
            CamporeeAgendaNowGroup(
              events: events,
              startDate: _camporee.startDate,
              padding: const EdgeInsets.only(bottom: 24),
              clock: ref.read(camporeeClockProvider),
              onOpenEvent: (event) =>
                  _openCamporeeEvent(context, _camporeeId, event),
            ),
          _WhenWhereGroup(camporee: _camporee),
          const SizedBox(height: 24),
          CamporeeSectionRegistrationGroup(
            registrationAsync: registrationAsync,
            onRetry: () => ref.invalidate(
              camporeeSectionRegistrationProvider(_camporeeId),
            ),
            onOpenParticipants: () => _selectTab(_CamporeeDetailTab.people),
          ),
          if (showDescription) ...[
            const SizedBox(height: 24),
            SacSettingsGroup(
              title: 'camporees.detail.description'.tr().toUpperCase(),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    description!,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      color: context.sac.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ];
      case _CamporeeDetailTab.people:
        return [
          _MembersGroup(
            camporeeId: _camporeeId,
            camporeeName: _camporee.name,
            membersAsync: membersAsync,
            participantsEnabled: participantsEnabled,
            readOnly: readOnly,
            registrationAsync: registrationAsync,
            onRetryMembers: () =>
                ref.invalidate(camporeeMembersProvider(_camporeeId)),
          ),
          _EnrollmentOrdersGroup(camporeeId: _camporeeId),
          if (participantsEnabled && !readOnly) ...[
            const SizedBox(height: 24),
            _ResourcesGroup(camporeeId: _camporeeId),
          ],
        ];
      case _CamporeeDetailTab.events:
        return [
          if (leaderboardAsync != null) ...[
            CamporeeLeaderboardPanel(
              leaderboardAsync: leaderboardAsync,
              ownSectionId: registrationAsync.value?.clubSectionId,
              onRetry: () =>
                  ref.invalidate(camporeeLeaderboardProvider(_camporeeId)),
            ),
            const SizedBox(height: 24),
          ],
          if (eventsAsync != null)
            _EventsSection(
              camporeeId: _camporeeId,
              eventsAsync: eventsAsync,
              scoreBreakdown: scoreBreakdown,
              ownSectionId: registrationAsync.value?.clubSectionId,
              scoredOnly: true,
              onRetry: () =>
                  ref.invalidate(camporeeEventsProvider(_camporeeId)),
            ),
        ];
      case _CamporeeDetailTab.agenda:
        return [
          if (eventsAsync?.value case final events?)
            CamporeeAgendaNowGroup(
              events: events,
              startDate: _camporee.startDate,
              padding: const EdgeInsets.only(bottom: 24),
              clock: ref.read(camporeeClockProvider),
              onOpenEvent: (event) =>
                  _openCamporeeEvent(context, _camporeeId, event),
            ),
          if (eventsAsync != null)
            _AgendaSection(
              camporeeId: _camporeeId,
              eventsAsync: eventsAsync,
              startDate: _camporee.startDate,
              onRetry: () =>
                  ref.invalidate(camporeeEventsProvider(_camporeeId)),
            ),
        ];
    }
  }
}

class _DetailTabBody extends StatelessWidget {
  final _CamporeeDetailTab tab;
  final int slide;
  final Widget child;

  const _DetailTabBody({
    required this.tab,
    required this.slide,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return AnimatedSwitcher(
      duration: reduce ? SacMotion.reducedFade : SacMotion.standard,
      switchInCurve: SacMotion.easeOut,
      switchOutCurve: SacMotion.easeOut,
      layoutBuilder: (current, previous) {
        return Stack(
          alignment: Alignment.topCenter,
          fit: StackFit.expand,
          children: [
            for (final old in previous) IgnorePointer(child: old),
            if (current != null) current,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (reduce) return fade;
        final incoming = child.key == ValueKey(tab);
        final begin = Offset((incoming ? 0.06 : -0.06) * slide, 0);
        return SlideTransition(
          position:
              Tween<Offset>(begin: begin, end: Offset.zero).animate(animation),
          child: fade,
        );
      },
      child: KeyedSubtree(
        key: ValueKey(tab),
        child: child,
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
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
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
                duration: reduce ? Duration.zero : SacMotion.standard,
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
                        // iOS segmented thumb: a raised surface pill, not
                        // an accent fill, so the content keeps the focus.
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXS),
                            boxShadow: [
                              BoxShadow(
                                color: c.shadow,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
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
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusXS),
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
      color: selected ? c.text : c.textSecondary,
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
            fontSize: SacFontSize.bodyMedium,
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
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
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
                      fontSize: SacFontSize.bodySmall,
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
                        color: SacAccent.of(context).color,
                        fontSize: SacFontSize.bodyMedium,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  Text(
                    'camporees.detail.event_honor_no_pdf'.tr(),
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: SacFontSize.bodySmall,
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

class _CamporeeEventDetailPage extends ConsumerWidget {
  final int camporeeId;
  final CamporeeEvent event;

  const _CamporeeEventDetailPage({
    required this.camporeeId,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final description = event.description?.trim();
    final hasSchedules = event.agendaVisible && event.scheduleBlocks.isNotEmpty;
    final hasStaffSummary = event.agendaVisible &&
        (event.responsibleDisplayNames.isNotEmpty ||
            event.supportingDisplayNames.isNotEmpty);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'camporees.detail.event_detail_title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: ListView(
              padding: SacTopBar.paddingBelowBar(
                  context, const EdgeInsets.fromLTRB(16, 20, 16, 40)),
              children: [
                _EventDetailHeader(event: event),
                const SizedBox(height: 18),
                _EventFactsPanel(event: event),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _DescriptionSection(description: description),
                ],
                CamporeeEventScoresGroup(
                  camporeeId: camporeeId,
                  event: event,
                ),
                _EventAttachmentsGroup(event: event),
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
                  _SectionHeader(
                      label: 'camporees.detail.event_schedules'.tr()),
                  const SizedBox(height: 10),
                  _ScheduleBlocksPreview(blocks: event.scheduleBlocks),
                ],
              ],
            ),
          ),
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

void _openCamporeeEvent(
  BuildContext context,
  int camporeeId,
  CamporeeEvent event,
) {
  HapticFeedback.selectionClick();
  Navigator.push(
    context,
    SacSharedAxisRoute(
      builder: (_) => _CamporeeEventDetailPage(
        camporeeId: camporeeId,
        event: event,
      ),
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
      return HugeIcons.strokeRoundedBackpack03;
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
      return SacAccent.of(context).color;
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
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
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
                    fontSize: SacFontSize.bodySmall,
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
                      fontSize: SacFontSize.labelSmall,
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
            fontSize: SacFontSize.bodySmall,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
            child: HugeIcon(
                icon: icon, size: 20, color: SacAccent.of(context).color),
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
                    fontSize: SacFontSize.bodySmall,
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
                    fontSize: SacFontSize.titleMedium,
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
  final double size;

  const _MemberAvatar({required this.member, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final imageUrl = member.userImageUrl;

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: SacAccent.of(context).color.withValues(alpha: 0.10),
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
        color: SacAccent.of(context).color,
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

  const _SurfacePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return SacCard(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: child,
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(
            context,
            EdgeInsets.fromLTRB(
              Responsive.horizontalPadding(context),
              24,
              Responsive.horizontalPadding(context),
              48,
            ),
          ),
          children: const [
            SacSkeletonCard(height: 88),
            SizedBox(height: 24),
            SacSkeletonCard(height: 220),
            SizedBox(height: 20),
            SacSkeletonCard(height: 220),
          ],
        ),
      ),
    );
  }
}

/// Who the camporee is for (club logos), its name and field, and where it
/// stands. The same pieces as the ticket in the list.
class _DetailHeader extends StatelessWidget {
  final Camporee camporee;
  final bool readOnly;

  const _DetailHeader({required this.camporee, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final status = CamporeeStatus.of(
      context,
      CamporeeTiming.of(camporee, DateTime.now()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CamporeeClubLogos(camporee: camporee, size: 56, dimmed: readOnly),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      camporee.name,
                      style: TextStyle(
                        fontSize: SacFontSize.titleLarge,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (camporee.localFieldName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      camporee.localFieldName!,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SacBadge(
                    key: const Key('camporee-detail-status'),
                    label: status.label,
                    variant: status.variant,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (readOnly) ...[
          const SizedBox(height: 12),
          Text(
            'camporees.detail.history_notice'.tr(),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: SacFontSize.bodyMedium,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Dates, place and cost as rows of one group. With coordinates the map
/// heads the group; the place row opens the map apps either way.
class _WhenWhereGroup extends StatelessWidget {
  final Camporee camporee;

  const _WhenWhereGroup({required this.camporee});

  void _openMaps(BuildContext context) {
    HapticFeedback.selectionClick();
    showCamporeeMapOptions(context, camporee);
  }

  void _copyPlace(BuildContext context) {
    Clipboard.setData(ClipboardData(text: camporee.place));
    SacSnackBar.show(
      context,
      'camporees.detail.address_copied'.tr(),
      isSuccess: true,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final place = camporee.place.trim();
    final hasMap = camporee.lat != null && camporee.longitude != null;
    final cost = camporee.registrationCost;
    final days = camporee.endDate.isBefore(camporee.startDate)
        ? 1
        : DateUtils.dateOnly(camporee.endDate)
                .difference(DateUtils.dateOnly(camporee.startDate))
                .inDays +
            1;

    final rows = <Widget>[
      _GroupFactRow(
        icon: HugeIcons.strokeRoundedCalendar03,
        label: 'camporees.detail.dates'.tr(),
        value: SacDateFormatter.range(camporee.startDate, camporee.endDate),
        sub: 'camporees.detail.duration_days'.plural(days),
      ),
      if (place.isNotEmpty)
        _GroupFactRow(
          key: const Key('camporee-detail-place'),
          icon: HugeIcons.strokeRoundedLocation01,
          label: 'camporees.detail.place'.tr(),
          value: place,
          onTap: () => _openMaps(context),
          onLongPress: () => _copyPlace(context),
        ),
      _GroupFactRow(
        icon: HugeIcons.strokeRoundedTicket01,
        label: 'camporees.detail.cost'.tr(),
        value: cost == null || cost == 0
            ? 'camporees.common.free'.tr()
            : SacMoney.format(cost),
        emphasis: true,
        valueColor: cost == null || cost == 0 ? c.onSuccessContainer : null,
      ),
    ];

    return SacSettingsGroup(
      title: 'camporees.detail.when_where'.tr().toUpperCase(),
      children: [
        if (hasMap && place.isNotEmpty) ...[
          GestureDetector(
            onTap: () => _openMaps(context),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMD - 1),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: IgnorePointer(
                  child: CamporeeMapPreview(camporee: camporee),
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: c.divider),
        ],
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SacSettingsDivider(),
          rows[i],
        ],
      ],
    );
  }
}

/// One fact: icon and label on the left, the value on the right.
class _GroupFactRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final String? sub;
  final bool emphasis;
  final Color? valueColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _GroupFactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.emphasis = false,
    this.valueColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            HugeIcon(icon: icon, size: 18, color: c.textSecondary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: emphasis
                          ? SacFontSize.titleMedium
                          : SacFontSize.bodyMedium,
                      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
                      color: valueColor ?? c.text,
                      height: 1.3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textTertiary,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 16,
                  color: c.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return MergeSemantics(
      child: SacInkWell(onTap: onTap, onLongPress: onLongPress, child: row),
    );
  }
}

/// The tab's main action pinned above the tab bar, always in reach:
/// «Inscribir mi sección» on Detalle, «Inscribir participantes» on
/// Asistentes.
class _PinnedAction extends StatelessWidget {
  final String text;
  final HugeIconData icon;
  final VoidCallback onPressed;

  const _PinnedAction({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderLight)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 12),
        child: SacButton.primary(
          text: text,
          icon: icon,
          onPressed: onPressed,
          labelMaxLines: 2,
          labelOverflow: TextOverflow.visible,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped-list pieces for the Asistentes, Eventos and Agenda tabs.
// ---------------------------------------------------------------------------

/// A plain message inside a group: locked, empty or failed states.
class _GroupMessageRow extends StatelessWidget {
  final HugeIconData icon;
  final Color? iconColor;
  final String text;
  final Widget? trailing;

  const _GroupMessageRow({
    required this.icon,
    required this.text,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 20, color: iconColor ?? c.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class _GroupLoadingRow extends StatelessWidget {
  final String? semanticsLabel;

  const _GroupLoadingRow({this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      liveRegion: semanticsLabel != null,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SacLoadingSmall()),
      ),
    );
  }
}

/// Small note under a group, like an iOS section footer.
class _GroupFooter extends StatelessWidget {
  final String text;

  const _GroupFooter(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: SacFontSize.bodySmall,
          color: context.sac.textTertiary,
          height: 1.35,
        ),
      ),
    );
  }
}

/// A tappable group row: leading widget, title and subtitle, trailing and a
/// chevron when it opens something.
class _GroupRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Extra line under the subtitle, e.g. a status badge too wide for the
  /// trailing slot.
  final Widget? below;
  final VoidCallback? onTap;
  final int titleMaxLines;

  const _GroupRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.below,
    this.onTap,
    this.titleMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      height: 1.3,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (below != null) ...[
                    const SizedBox(height: 6),
                    below!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 16,
                  color: c.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return MergeSemantics(child: SacInkWell(onTap: onTap, child: row));
  }
}

List<Widget> _withDividers(List<Widget> rows) => [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SacSettingsDivider(),
        rows[i],
      ],
    ];

// --- Asistentes -------------------------------------------------------------

class _MembersGroup extends StatelessWidget {
  final int camporeeId;
  final String camporeeName;
  final AsyncValue<List<CamporeeMember>> membersAsync;
  final bool participantsEnabled;
  final bool readOnly;
  final AsyncValue<CamporeeSectionRegistration> registrationAsync;
  final VoidCallback onRetryMembers;

  const _MembersGroup({
    required this.camporeeId,
    required this.camporeeName,
    required this.membersAsync,
    required this.participantsEnabled,
    required this.readOnly,
    required this.registrationAsync,
    required this.onRetryMembers,
  });

  static const int _preview = 3;

  void _openAll(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      SacSharedAxisRoute(
        builder: (context) => CamporeeMembersView(
          camporeeId: camporeeId,
          camporeeName: camporeeName,
          readOnly: readOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final title = 'camporees.detail.members_enrolled'.tr().toUpperCase();
    final count = participantsEnabled ? membersAsync.value?.length : null;

    final List<Widget> rows;
    if (!participantsEnabled) {
      rows = [
        Semantics(
          liveRegion: registrationAsync.isLoading || registrationAsync.hasError,
          child: _GroupMessageRow(
            icon: HugeIcons.strokeRoundedLockKey,
            text: 'camporees.section_registration.participants_locked'.tr(),
          ),
        ),
      ];
    } else {
      rows = membersAsync.when(
        loading: () => [
          _GroupLoadingRow(
            semanticsLabel: 'camporees.detail.members_loading'.tr(),
          ),
        ],
        error: (_, __) => [
          _GroupMessageRow(
            icon: HugeIcons.strokeRoundedAlert02,
            iconColor: c.warning,
            text: 'camporees.detail.members_error'.tr(),
            trailing: SacButton.text(
              text: 'camporees.section_registration.retry'.tr(),
              onPressed: onRetryMembers,
            ),
          ),
        ],
        data: (members) {
          if (members.isEmpty) {
            return [
              _GroupMessageRow(
                icon: HugeIcons.strokeRoundedUserGroup,
                text: 'camporees.detail.no_members_yet'.tr(),
              ),
            ];
          }
          return _withDividers([
            for (final member in members.take(_preview))
              _GroupRow(
                leading: _MemberAvatar(member: member, size: 36),
                title: member.userName ?? member.userId,
                subtitle: member.clubName,
                trailing: member.insuranceVerified
                    ? SacBadge.success(
                        label: 'camporees.detail.insurance_short'.tr(),
                      )
                    : SacBadge.error(
                        label: 'camporees.detail.no_insurance'.tr(),
                      ),
              ),
            SacSettingsTile(
              icon: HugeIcons.strokeRoundedUserGroup,
              title: 'camporees.detail.view_all_members'
                  .tr(namedArgs: {'count': '${members.length}'}),
              onTap: () => _openAll(context),
            ),
          ]);
        },
      );
    }

    return SacSettingsGroup(
      key: const Key('camporee-members-group'),
      title: count == null ? title : '$title · $count',
      children: rows,
    );
  }
}

class _EnrollmentOrdersGroup extends ConsumerWidget {
  final int camporeeId;

  const _EnrollmentOrdersGroup({required this.camporeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersContext = ref.watch(paymentOrdersContextProvider);
    if (ordersContext.value?.enabled != true) {
      return const SizedBox.shrink();
    }
    final ordersAsync = ref.watch(
      paymentOrdersListProvider(
        PaymentOrdersFilter(
          purpose: PaymentOrderPurpose.camporee,
          camporeeId: camporeeId,
        ),
      ),
    );
    final c = context.sac;

    final rows = ordersAsync.when<List<Widget>>(
      loading: () => const [_GroupLoadingRow()],
      error: (_, __) => [
        _GroupMessageRow(
          icon: HugeIcons.strokeRoundedAlert02,
          iconColor: c.warning,
          text: 'camporees.detail.enrollment_orders_error'.tr(),
        ),
      ],
      data: (orders) {
        if (orders.isEmpty) {
          return [
            _GroupMessageRow(
              icon: HugeIcons.strokeRoundedInvoice01,
              text: 'camporees.detail.enrollment_orders_empty'.tr(),
            ),
          ];
        }
        return _withDividers([
          for (final order in orders)
            _GroupRow(
              key: ValueKey('camporee-order-${order.orderId}'),
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedInvoice01,
                size: 20,
                color: c.textSecondary,
              ),
              title: order.folioReference,
              titleMaxLines: 1,
              subtitle: [
                SacMoney.fromCentavos(order.totalCentavos),
                if (order.lines.isNotEmpty)
                  'camporees.detail.order_members'.plural(order.lines.length),
              ].join(' · '),
              // Under the amount: "Comprobante enviado" is too wide to sit
              // next to the folio without cutting it.
              below: PaymentOrderStatusBadge(status: order.status),
              onTap: () => context.push(
                RouteNames.paymentOrderDetailPath(order.orderId),
              ),
            ),
        ]);
      },
    );

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SacSettingsGroup(
        title: 'camporees.detail.enrollment_orders'.tr().toUpperCase(),
        children: rows,
      ),
    );
  }
}

class _ResourcesGroup extends StatelessWidget {
  final int camporeeId;

  const _ResourcesGroup({required this.camporeeId});

  @override
  Widget build(BuildContext context) {
    return SacSettingsGroup(
      title: 'camporees.detail.resources'.tr().toUpperCase(),
      children: [
        CamporeeSuppliesCta(camporeeId: camporeeId, embedded: true),
        CamporeeOrdersCta(camporeeId: camporeeId, embedded: true),
      ],
    );
  }
}

// --- Eventos ----------------------------------------------------------------

class _EventsSection extends StatelessWidget {
  final int camporeeId;
  final AsyncValue<List<CamporeeEvent>> eventsAsync;
  final VoidCallback onRetry;
  final bool scoredOnly;

  /// Club roles get their own points in each row's trailing.
  final CamporeeScoreBreakdown? scoreBreakdown;
  final int? ownSectionId;

  const _EventsSection({
    required this.camporeeId,
    required this.eventsAsync,
    required this.onRetry,
    this.scoredOnly = false,
    this.scoreBreakdown,
    this.ownSectionId,
  });

  /// «430 / 500» or «No se presentó» for the user's section; null when the
  /// visibility is not `own` or the section has no result for [event] yet.
  String? _ownScoreLabel(CamporeeEvent event) {
    final breakdown = scoreBreakdown;
    if (breakdown == null || !breakdown.isOwn) return null;
    final entries = breakdown.entriesForEvent(event.camporeeEventId);
    if (entries.isEmpty) return null;
    final entry = entries.firstWhere(
      (e) => e.section.clubSectionId == ownSectionId,
      orElse: () => entries.first,
    );
    final score = entry.result.score;
    return score.isNoShow
        ? 'camporees.detail.score_no_show'.tr()
        : camporeeScoreFraction(score);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    var count = 0;
    final rows = eventsAsync.when<List<Widget>>(
      loading: () => const [_GroupLoadingRow()],
      error: (_, __) => [
        _GroupMessageRow(
          icon: HugeIcons.strokeRoundedAlert02,
          iconColor: c.error,
          text: 'camporees.detail.events_error'.tr(),
          trailing: SacButton.text(
            text: 'camporees.section_registration.retry'.tr(),
            onPressed: onRetry,
          ),
        ),
      ],
      data: (events) {
        final visible = scoredOnly
            ? events.where((event) => event.isScored).toList()
            : events;
        count = visible.length;
        if (visible.isEmpty) {
          return [
            _GroupMessageRow(
              icon: HugeIcons.strokeRoundedCalendar03,
              text: scoredOnly
                  ? 'camporees.detail.no_scored_events'.tr()
                  : 'camporees.detail.no_events_yet'.tr(),
            ),
          ];
        }
        return _withDividers([
          for (final event in visible)
            _GroupRow(
              key: ValueKey(event.camporeeEventId),
              leading: _IconTile(
                icon: _eventCategoryIcon(event.displayCategory),
                color: _eventCategoryColor(context, event.displayCategory),
                size: 34,
              ),
              title: event.title,
              subtitle: _eventWhenWhere(event),
              trailing: Text(
                _ownScoreLabel(event) ??
                    'camporees.detail.event_points'
                        .tr(namedArgs: {'points': '${event.maxPoints}'}),
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              onTap: () => _openCamporeeEvent(context, camporeeId, event),
            ),
        ]);
      },
    );
    final title = 'camporees.detail.events_scored_title'.tr().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacSettingsGroup(
          key: const Key('camporee-events-group'),
          title: count > 0 ? '$title · $count' : title,
          children: rows,
        ),
        _GroupFooter('camporees.detail.events_subtitle'.tr()),
      ],
    );
  }
}

/// «Día 1 · 10:00 · Explanada», or the pending note when it has no slot yet.
String _eventWhenWhere(CamporeeEvent event) {
  if (!event.agendaVisible) return 'camporees.detail.agenda_pending'.tr();
  final venue = event.venueName?.trim();
  return [
    'camporees.detail.event_day'.tr(namedArgs: {'day': '${event.dayNumber}'}),
    if (formatCamporeeClock(event.startsAt) != null)
      formatCamporeeClock(event.startsAt)!,
    if (venue != null && venue.isNotEmpty) venue,
  ].join(' · ');
}

// --- Agenda -----------------------------------------------------------------

class _AgendaSection extends StatelessWidget {
  final int camporeeId;
  final AsyncValue<List<CamporeeEvent>> eventsAsync;
  final DateTime startDate;
  final VoidCallback onRetry;

  const _AgendaSection({
    required this.camporeeId,
    required this.eventsAsync,
    required this.startDate,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final locale = context.locale.languageCode;

    return eventsAsync.when(
      loading: () => const SacSettingsGroup(children: [_GroupLoadingRow()]),
      error: (_, __) => SacSettingsGroup(
        children: [
          _GroupMessageRow(
            icon: HugeIcons.strokeRoundedAlert02,
            iconColor: c.error,
            text: 'camporees.detail.events_error'.tr(),
            trailing: SacButton.text(
              text: 'camporees.section_registration.retry'.tr(),
              onPressed: onRetry,
            ),
          ),
        ],
      ),
      data: (events) {
        if (events.isEmpty) {
          return SacSettingsGroup(
            title: 'camporees.detail.agenda_title'.tr().toUpperCase(),
            children: [
              _GroupMessageRow(
                icon: HugeIcons.strokeRoundedCalendar03,
                text: 'camporees.detail.agenda_empty'.tr(),
              ),
            ],
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

        String dayTitle(int day) {
          final date = SacDateFormatter.formatCalendar(
            camporeeAgendaDayDate(startDate, day),
            'EEE d MMM',
            locale: locale,
          );
          final label =
              'camporees.detail.event_day'.tr(namedArgs: {'day': '$day'});
          return (date.isEmpty ? label : '$label · $date').toUpperCase();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var g = 0; g < groups.length; g++) ...[
              if (g > 0) const SizedBox(height: 24),
              SacSettingsGroup(
                title: dayTitle(groups[g].$1),
                children: _withDividers([
                  for (final entry in groups[g].$2)
                    _AgendaRow(
                      camporeeId: camporeeId,
                      entry: entry,
                      showSchedule: true,
                    ),
                ]),
              ),
            ],
            if (pending.isNotEmpty) ...[
              if (groups.isNotEmpty) const SizedBox(height: 24),
              SacSettingsGroup(
                title: 'camporees.detail.agenda_pending'.tr().toUpperCase(),
                children: _withDividers([
                  for (final entry in pending)
                    _AgendaRow(
                      camporeeId: camporeeId,
                      entry: entry,
                      showSchedule: false,
                    ),
                ]),
              ),
            ],
            _GroupFooter('camporees.detail.agenda_subtitle'.tr()),
          ],
        );
      },
    );
  }
}

/// One slot of the program: time, a dot in the category color, the
/// activity and where it happens.
class _AgendaRow extends StatelessWidget {
  final int camporeeId;
  final CamporeeAgendaEntry entry;
  final bool showSchedule;

  const _AgendaRow({
    required this.camporeeId,
    required this.entry,
    required this.showSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final event = entry.event;
    final clock = showSchedule ? formatCamporeeClock(entry.startsAt) : null;
    final typeLabel = _eventTypeLabel(event);
    final venue = showSchedule ? entry.venueName?.trim() : null;

    return _GroupRow(
      key: Key(
        'camporee-agenda-${event.camporeeEventId}-${entry.dayNumber}-${entry.startsAt ?? 'none'}',
      ),
      leading: SizedBox(
        width: 58,
        child: Row(
          children: [
            Expanded(
              child: Text(
                clock ?? '—',
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w600,
                  color: clock == null ? c.textTertiary : c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _eventCategoryColor(context, event.displayCategory),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      title: entry.headline,
      subtitle: [
        if (typeLabel.isNotEmpty) typeLabel,
        if (venue != null && venue.isNotEmpty) venue,
      ].join(' · '),
      onTap: () => _openCamporeeEvent(context, camporeeId, event),
    );
  }
}

// --- Adjuntos del evento ----------------------------------------------------

/// Files the organizer attached to the event (rules, maps, forms). Fetched
/// when the page opens because the signed urls in the list expire; while
/// loading it shows the ones that came with the event. Hidden when empty.
class _EventAttachmentsGroup extends ConsumerWidget {
  final CamporeeEvent event;

  const _EventAttachmentsGroup({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fresh =
        ref.watch(camporeeEventAttachmentsProvider(event.camporeeEventId));
    final attachments = fresh.value ?? event.attachments;
    if (attachments.isEmpty) return const SizedBox.shrink();

    final images = [
      for (final item in attachments)
        if (item.isImage) item,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SacSettingsGroup(
        key: const Key('camporee-event-attachments'),
        title: '${'camporees.detail.attachments_title'.tr().toUpperCase()}'
            ' · ${attachments.length}',
        children: _withDividers([
          for (final item in attachments)
            _GroupRow(
              key: ValueKey('camporee-event-attachment-${item.attachmentId}'),
              leading: _IconTile(
                icon: item.isPdf
                    ? HugeIcons.strokeRoundedPdf01
                    : HugeIcons.strokeRoundedImage01,
                color: item.isPdf ? context.sac.error : context.sac.info,
                size: 34,
              ),
              title: item.fileName,
              subtitle: [
                item.isPdf
                    ? 'camporees.detail.attachment_pdf'.tr()
                    : 'camporees.detail.attachment_image'.tr(),
                if (item.sizeBytes > 0) _formatFileSize(item.sizeBytes),
              ].join(' · '),
              onTap: () {
                HapticFeedback.selectionClick();
                if (item.isPdf) {
                  SacPdfViewer.show(
                    context,
                    pdfSource: item.url,
                    title: item.fileName,
                  );
                } else {
                  SacImageViewer.show(
                    context,
                    imageUrl: item.url,
                    title: item.fileName,
                    imageUrls: [for (final image in images) image.url],
                    initialIndex: images.indexOf(item),
                  );
                }
              },
            ),
        ]),
      ),
    );
  }
}

/// «2.4 MB», «850 KB».
String _formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}
