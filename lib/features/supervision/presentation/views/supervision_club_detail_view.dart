import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_clubs_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_plain_row.dart';
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: name.isEmpty ? title : name,
        subtitle: name.isEmpty ? null : title,
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

    SacGroupedSection facts(String key, List<Widget> rows) => SacGroupedSection(
          label: 'supervision.clubs.$key'.tr(),
          dividerIndent: 16,
          // A count of rows says nothing here.
          action: const SizedBox.shrink(),
          children: rows,
        );

    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.clubs.$key'.tr(),
          value: value,
        );

    final leaders = <(String, SupervisionClubLeader)>[
      if (leadership?.director != null)
        ('supervision.clubs.role_director', leadership!.director!),
      for (final person in leadership?.deputies ?? const [])
        ('supervision.clubs.role_deputy', person),
      for (final person in leadership?.secretaries ?? const [])
        ('supervision.clubs.role_secretary', person),
    ].where((entry) => entry.$2.fullName.trim().isNotEmpty).toList();

    final attendance = overview?.attendanceAverage;
    final events = overview?.upcomingEvents ?? const <SupervisionClubEvent>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        facts('about_title', [
          row(
            'status',
            (profile.active
                    ? 'supervision.clubs.status_active'
                    : 'supervision.clubs.status_inactive')
                .tr(),
          ),
          if (profile.churchName.isNotEmpty) row('church', profile.churchName),
          if (profile.districtName.isNotEmpty)
            row('district', profile.districtName),
          if (profile.localFieldName.isNotEmpty)
            row('local_field', profile.localFieldName),
          if ((profile.address ?? '').trim().isNotEmpty)
            row('address', profile.address!),
        ]),
        if (overview != null)
          facts('year_title', [
            row(
              'active_members',
              supervisionCount(context, overview.activeMembers),
            ),
            row(
              'invested',
              supervisionCount(context, overview.investedThisYear),
            ),
            row(
              'pending_requests',
              supervisionCount(context, overview.pendingRequests),
            ),
            if (attendance != null)
              row('attendance', supervisionPercent(attendance)),
          ])
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
            dividerIndent: 16,
            children: [
              for (final section in profile.sections)
                SupervisionPlainRow(
                  title: section.typeName.isEmpty
                      ? 'supervision.clubs.section_unnamed'.tr()
                      : section.typeName,
                  subtitle: [
                    if (!section.active)
                      'supervision.clubs.section_inactive'.tr(),
                    if (section.soulsTarget != null && section.soulsTarget! > 0)
                      'supervision.clubs.section_target'.tr(
                        args: [supervisionCount(context, section.soulsTarget!)],
                      ),
                  ].join(' · '),
                ),
            ],
          ),
        if (leaders.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.clubs.leadership_title'.tr(),
            dividerIndent: 16,
            action: const SizedBox.shrink(),
            children: [
              for (final (roleKey, person) in leaders)
                SupervisionPlainRow(
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
            dividerIndent: 16,
            children: [
              for (final event in events)
                SupervisionPlainRow(
                  title: event.name,
                  subtitle: [
                    if (event.date != null)
                      supervisionShortDate(context, event.date!),
                    if (event.sectionName != null) event.sectionName!,
                  ].join(' · '),
                ),
            ],
          ),
      ],
    );
  }
}
