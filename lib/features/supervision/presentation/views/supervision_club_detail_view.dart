import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_clubs_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_figures_card.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_identity_tiles.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';

/// Summary of one club of the territory: where it is, who leads it, how it
/// is doing this year and what it has coming. Read only.
class SupervisionClubDetailView extends ConsumerWidget {
  const SupervisionClubDetailView({super.key, required this.clubId});

  /// Path parameter; anything that is not a club id shows the error state.
  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final id = int.tryParse(clubId);
    final title = 'supervision.clubs.detail_title'.tr();

    if (id == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: c.background,
        appBar: SacTopBar(title: title, frosted: true),
        body: SacFrostedVeil(
          child: SupervisionScroll(
            onRefresh: () async {},
            fill: true,
            child: SacErrorState(
              title: 'supervision.clubs.detail_error_title'.tr(),
              message: 'supervision.clubs.error_message'.tr(),
            ),
          ),
        ),
      );
    }

    final provider = supervisionClubSummaryProvider(id);
    final async = ref.watch(provider);
    // A failed refresh keeps the last summary on screen.
    final summary = async.value;

    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {
        // The body renders the error.
      }
    }

    final Widget body;
    if (summary == null && async.hasError) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: isForbiddenFailure(async.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.clubs.detail_error_title'.tr(),
                message: 'supervision.clubs.error_message'.tr(),
                onRetry: refresh,
              ),
      );
    } else if (summary == null) {
      body = SupervisionScroll(
        onRefresh: refresh,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: SacSkeletonList(
            itemCount: 6,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    } else {
      body = SupervisionScroll(
        onRefresh: refresh,
        child: _Summary(summary: summary),
      );
    }

    final name = summary?.profile.name.trim() ?? '';
    // The local field says whose club it is; before it loads (or when the
    // club carries none) the bar keeps naming the screen.
    final field = summary?.profile.localFieldName.trim() ?? '';
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: name.isEmpty ? title : name,
        subtitle: name.isEmpty ? null : (field.isEmpty ? title : field),
        frosted: true,
      ),
      body: SacFrostedVeil(child: body),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final SupervisionClubSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final profile = summary.profile;
    final overview = summary.overview;
    final leadership = summary.leadership;

    final leaders = <(String, SupervisionClubLeader)>[
      if (leadership?.director != null)
        ('supervision.clubs.role_director', leadership!.director!),
      for (final person in leadership?.deputies ?? const [])
        ('supervision.clubs.role_deputy', person),
      for (final person in leadership?.secretaries ?? const [])
        ('supervision.clubs.role_secretary', person),
    ].where((entry) => entry.$2.fullName.trim().isNotEmpty).toList();

    final events = overview?.upcomingEvents ?? const <SupervisionClubEvent>[];
    final facts = <(String, String)>[
      ('church', profile.churchName),
      ('district', profile.districtName),
      ('address', profile.address ?? ''),
    ].where((fact) => fact.$2.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!profile.active) const _InactivePanel(),
        if (overview != null)
          _Figures(overview: overview)
        else
          // The club itself loaded; only its figures did not.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text(
              'supervision.clubs.overview_unavailable'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                height: 1.3,
                color: c.textSecondary,
              ),
            ),
          ),
        if (profile.sections.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.clubs.sections_title'.tr(),
            dividerIndent: 64,
            children: [
              for (final section in profile.sections)
                _SectionRow(section: section),
            ],
          ),
        if (leaders.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.clubs.leadership_title'.tr(),
            dividerIndent: 64,
            children: [
              for (final (roleKey, person) in leaders)
                SacListRow(
                  leading: SupervisionInitialsAvatar(name: person.fullName),
                  title: person.fullName,
                  subtitle: [
                    roleKey.tr(),
                    if (person.sectionName != null) person.sectionName!,
                  ].join(' · '),
                ),
            ],
          ),
        if (events.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.clubs.events_title'.tr(),
            dividerIndent: 70,
            children: [
              for (final event in events)
                SacListRow(
                  leading: SupervisionDateTile(date: event.date),
                  title: event.name,
                  subtitle: [
                    if (event.date != null)
                      supervisionShortDate(context, event.date!),
                    if (event.sectionName != null) event.sectionName!,
                  ].join(' · '),
                ),
            ],
          ),
        if (facts.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.clubs.facts_title'.tr(),
            dividerIndent: 16,
            // A count of rows says nothing here.
            action: const SizedBox.shrink(),
            children: [
              for (final (key, value) in facts)
                SacValueRow(
                  label: 'supervision.clubs.$key'.tr(),
                  value: value,
                ),
            ],
          ),
      ],
    );
  }
}

/// The club is inactive: that is the first thing to read, so it is a panel
/// and not a «Estado: Inactivo» row among the data.
class _InactivePanel extends StatelessWidget {
  const _InactivePanel();

  @override
  Widget build(BuildContext context) {
    final title = 'supervision.clubs.inactive_title'.tr();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SacStatePanel(
        style: SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: title,
          icon: HugeIcons.strokeRoundedInformationCircle,
        ),
        title: title,
        message: 'supervision.clubs.inactive_body'.tr(),
      ),
    );
  }
}

/// Members, invested, attendance and the pending role requests. The pending
/// ones read in the warning tone when there are any.
class _Figures extends StatelessWidget {
  const _Figures({required this.overview});

  final SupervisionClubOverview overview;

  @override
  Widget build(BuildContext context) {
    final attendance = overview.attendanceAverage;
    return SupervisionFiguresCard(
      figures: [
        SupervisionFigure(
          value: supervisionCount(context, overview.activeMembers),
          label: 'supervision.clubs.active_members'.tr(),
        ),
        SupervisionFigure(
          value: supervisionCount(context, overview.investedThisYear),
          label: 'supervision.clubs.invested'.tr(),
        ),
        // No attendance data: the figure leaves instead of showing a zero.
        if (attendance != null)
          SupervisionFigure(
            value: supervisionPercent(attendance),
            label: 'supervision.clubs.attendance'.tr(),
          ),
        SupervisionFigure(
          value: supervisionCount(context, overview.pendingRequests),
          label: 'supervision.clubs.pending_roles'.tr(),
          tone: overview.pendingRequests > 0 ? SacTone.warning : null,
        ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section});

  final SupervisionClubSection section;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = section.typeName.isEmpty
        ? 'supervision.clubs.section_unnamed'.tr()
        : section.typeName;
    final target = section.soulsTarget;
    final subtitle = [
      if (!section.active) 'supervision.clubs.section_inactive'.tr(),
      if (target != null && target > 0)
        'supervision.clubs.section_target'
            .tr(args: [supervisionCount(context, target)]),
    ].join(' · ');
    return SacListRow(
      leading: SupervisionClubTypeLogo(typeName: section.typeName),
      title: name,
      titleColor: section.active ? null : c.textTertiary,
      subtitle: subtitle,
    );
  }
}
