import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_member.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_location_card.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_panel.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_sheet.dart';

import '../providers/camporees_providers.dart';
import 'camporee_members_view.dart';
import 'camporee_register_member_view.dart';

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

  const _CamporeeScaffold({required this.body});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

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
          'camporees.list.title'.tr(),
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
      body: SafeArea(top: false, child: body),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Camporee camporee;
  final int camporeeId;

  const _DetailBody({
    required this.camporee,
    required this.camporeeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const eventViewerRoles = {
      ClubRoleNames.director,
      ClubRoleNames.deputyDirector,
      ClubRoleNames.secretary,
      ClubRoleNames.treasurer,
      ClubRoleNames.secretaryTreasurer,
      ClubRoleNames.counselor,
    };
    final user = ref.watch(
      authNotifierProvider.select((value) => value.valueOrNull),
    );
    final canViewEvents = hasAnyRole(user, eventViewerRoles);
    final registrationAsync =
        ref.watch(camporeeSectionRegistrationProvider(camporeeId));
    final participantsEnabled =
        camporeeParticipantsAreEnabled(registrationAsync);
    final membersAsync = participantsEnabled
        ? ref.watch(camporeeMembersProvider(camporeeId))
        : const AsyncData<List<CamporeeMember>>(<CamporeeMember>[]);
    final eventsAsync =
        canViewEvents ? ref.watch(camporeeEventsProvider(camporeeId)) : null;
    final description = camporee.description?.trim();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(camporeeDetailProvider(camporeeId));
        ref.invalidate(camporeeSectionRegistrationProvider(camporeeId));
        if (participantsEnabled) {
          ref.invalidate(camporeeMembersProvider(camporeeId));
        }
        if (canViewEvents) {
          ref.invalidate(camporeeEventsProvider(camporeeId));
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _TitleSection(camporee: camporee),
          const SizedBox(height: 12),
          _CamporeeDetailBanner(camporee: camporee),
          const SizedBox(height: 12),
          _CamporeeFactsPanel(camporee: camporee),
          const SizedBox(height: 24),
          CamporeeLocationCard(camporee: camporee),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 24),
            _DescriptionSection(description: description),
          ],
          const SizedBox(height: 24),
          CamporeeSectionRegistrationPanel(
            registrationAsync: registrationAsync,
            onRetry: () => ref.invalidate(
              camporeeSectionRegistrationProvider(camporeeId),
            ),
            onEnroll: () {
              final registration = registrationAsync.valueOrNull;
              if (registration == null || !registration.canEnroll) return;
              CamporeeSectionRegistrationSheet.show(
                context,
                camporee: camporee,
                registration: registration,
              );
            },
            onManageParticipants: () => _openParticipants(context),
          ),
          const SizedBox(height: 24),
          _MembersSection(
            camporeeId: camporeeId,
            camporeeName: camporee.name,
            membersAsync: membersAsync,
            participantsEnabled: participantsEnabled,
            registrationAsync: registrationAsync,
            onRetryMembers: () =>
                ref.invalidate(camporeeMembersProvider(camporeeId)),
          ),
          if (eventsAsync != null) ...[
            const SizedBox(height: 24),
            _EventsSection(
              eventsAsync: eventsAsync,
              onRetry: () => ref.invalidate(camporeeEventsProvider(camporeeId)),
            ),
          ],
        ],
      ),
    );
  }

  void _openParticipants(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CamporeeRegisterMemberView(
          camporeeId: camporeeId,
        ),
      ),
    );
  }
}

class _CamporeeDetailBanner extends StatelessWidget {
  final Camporee camporee;

  const _CamporeeDetailBanner({required this.camporee});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM', context.locale.toString());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCampfire,
                size: 21,
                color: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'camporees.detail.banner_title'.tr(),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFormat.format(camporee.startDate.toLocal())} – ${dateFormat.format(camporee.endDate.toLocal())}',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

class _TitleSection extends StatelessWidget {
  final Camporee camporee;

  const _TitleSection({required this.camporee});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconTile(
              icon: HugeIcons.strokeRoundedCampfire,
              color: AppColors.primary,
              size: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                camporee.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ClubTypeBadges(camporee: camporee),
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
        '${dateFormat.format(camporee.startDate.toLocal())} – ${dateFormat.format(camporee.endDate.toLocal())}';

    return _SurfacePanel(
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

class _EventsSection extends StatelessWidget {
  final AsyncValue<List<CamporeeEvent>> eventsAsync;
  final VoidCallback onRetry;

  const _EventsSection({
    required this.eventsAsync,
    required this.onRetry,
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
              if (events.isEmpty) {
                return _EmptyInlineState(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  label: 'camporees.detail.no_events_yet'.tr(),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < events.length; index++)
                    StaggeredListItem(
                      index: index,
                      initialDelay: Duration.zero,
                      staggerDelay: const Duration(milliseconds: 35),
                      child: _EventTile(
                        key: ValueKey(events[index].camporeeEventId),
                        event: events[index],
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
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _CamporeeEventDetailPage(event: event),
              ),
            );
          },
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
  final AsyncValue<CamporeeSectionRegistration> registrationAsync;
  final VoidCallback onRetryMembers;

  const _MembersSection({
    required this.camporeeId,
    required this.camporeeName,
    required this.membersAsync,
    required this.participantsEnabled,
    required this.registrationAsync,
    required this.onRetryMembers,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
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
          const SizedBox(height: 14),
          SacButton.primary(
            text: 'camporees.detail.enroll'.tr(),
            icon: HugeIcons.strokeRoundedUserAdd01,
            isEnabled: participantsEnabled,
            onPressed: participantsEnabled
                ? () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CamporeeRegisterMemberView(
                          camporeeId: camporeeId,
                        ),
                      ),
                    );
                  }
                : null,
            backgroundColor: AppColors.primary,
            textColor: AppColors.ink900,
            labelMaxLines: 2,
            labelOverflow: TextOverflow.visible,
          ),
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
        for (var index = 0; index < preview.length; index++)
          StaggeredListItem(
            index: index,
            initialDelay: Duration.zero,
            staggerDelay: const Duration(milliseconds: 40),
            child: _MemberPreviewTile(member: preview[index]),
          ),
        const SizedBox(height: 12),
        SacButton.outline(
          text: 'camporees.detail.view_all_members'
              .tr(namedArgs: {'count': '${members.length}'}),
          icon: HugeIcons.strokeRoundedUserGroup,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (member.clubName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    member.clubName!,
                    style: TextStyle(
                      fontSize: 12,
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
          _InsuranceBadge(verified: member.insuranceVerified),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: HugeIcon(icon: icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: context.sac.divider),
    );
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

class _InsuranceBadge extends StatelessWidget {
  final bool verified;

  const _InsuranceBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? context.sac.success : context.sac.error;
    final label = verified
        ? 'camporees.detail.insurance_ok'.tr()
        : 'camporees.detail.no_insurance'.tr();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
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
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
        ),
      ],
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
    final c = context.sac;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borderLight),
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderLight),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 238,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderLight),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderLight),
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
