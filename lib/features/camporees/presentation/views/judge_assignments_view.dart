import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_judge_assignment.dart';

import '../providers/camporees_providers.dart';

/// Lista de asignaciones donde el usuario actual es juez principal.
///
/// Agrupa por evento: una card por prueba, filas tappable por club.
class JudgeAssignmentsView extends ConsumerWidget {
  const JudgeAssignmentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(camporeeJudgeAssignmentsProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        backgroundColor: c.surfaceVariant,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const SacBackButton(),
        title: Text('camporees.judge.assignments_title'.tr()),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(camporeeJudgeAssignmentsProvider);
          },
          child: assignmentsAsync.when(
            data: (assignments) {
              final primaryAssignments = assignments
                  .where((assignment) => assignment.canCaptureOfficialScore)
                  .toList();

              if (primaryAssignments.isEmpty) {
                return _EmptyAssignments(onRetry: () {
                  ref.invalidate(camporeeJudgeAssignmentsProvider);
                });
              }

              final groups = _groupJudgeAssignmentsByEvent(primaryAssignments);

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: groups.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _InboxSummary(
                        clubCount: primaryAssignments.length,
                        eventCount: groups.length,
                      ),
                    );
                  }

                  final groupIndex = index - 1;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: groupIndex == groups.length - 1 ? 0 : 14,
                    ),
                    child: StaggeredListItem(
                      index: groupIndex,
                      child: _EventAssignmentCard(
                        assignments: groups[groupIndex],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: SacLoading()),
            error: (error, _) => _ErrorAssignments(
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: () => ref.invalidate(camporeeJudgeAssignmentsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxSummary extends StatelessWidget {
  final int clubCount;
  final int eventCount;

  const _InboxSummary({
    required this.clubCount,
    required this.eventCount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SacBadge(
          label: 'camporees.judge.clubs_count'.plural(clubCount, name: 'count'),
          icon: HugeIcons.strokeRoundedUserGroup,
          variant: SacBadgeVariant.primary,
        ),
        SacBadge(
          label:
              'camporees.judge.events_count'.plural(eventCount, name: 'count'),
          icon: HugeIcons.strokeRoundedNoteEdit,
          variant: SacBadgeVariant.neutral,
        ),
      ],
    );
  }
}

class _EventAssignmentCard extends StatelessWidget {
  final List<CamporeeJudgeAssignment> assignments;

  const _EventAssignmentCard({required this.assignments});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;
    final eventTitle = _eventTitleOf(assignments.first);
    final labelCounts = <String, int>{};
    for (final assignment in assignments) {
      final label = _clubLabelOf(assignment);
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }

    return SacCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TintedMark(
                  background: scheme.primaryContainer,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedNoteEdit,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  height: 1.15,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'camporees.judge.clubs_count'.plural(
                          assignments.length,
                          name: 'count',
                        ),
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: c.divider),
          for (var i = 0; i < assignments.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: c.divider,
                indent: 64,
                endIndent: 16,
              ),
            _ClubScoreRow(
              assignment: assignments[i],
              eventTitle: eventTitle,
              subtitle: _clubSubtitleOf(
                assignments[i],
                needsDisambiguation:
                    (labelCounts[_clubLabelOf(assignments[i])] ?? 0) > 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClubScoreRow extends StatelessWidget {
  final CamporeeJudgeAssignment assignment;
  final String eventTitle;
  final String? subtitle;

  const _ClubScoreRow({
    required this.assignment,
    required this.eventTitle,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;
    final clubLabel = _clubLabelOf(assignment);

    return SacPressable(
      semanticLabel: 'camporees.judge.score_row_semantics'.tr(
        namedArgs: {
          'club': clubLabel,
          'event': eventTitle,
        },
      ),
      onTap: () {
        context.push(
          RouteNames.camporeeJudgeScoreEntryPath(
            assignment.eventId,
            assignment.clubSectionId,
            eventTitle: eventTitle,
            clubLabel: clubLabel,
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              _TintedMark(
                background: c.surfaceVariant,
                child: clubLabel.length <= 3
                    ? HugeIcon(
                        icon: HugeIcons.strokeRoundedUserGroup,
                        size: 16,
                        color: c.textSecondary,
                      )
                    : Text(
                        _clubInitials(clubLabel),
                        style: TextStyle(
                          color: c.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      clubLabel,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'camporees.judge.score_row_action'.tr(),
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TintedMark extends StatelessWidget {
  final Color background;
  final Widget child;

  const _TintedMark({
    required this.background,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: child,
    );
  }
}

class _EmptyAssignments extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyAssignments({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 96),
        HugeIcon(
          icon: HugeIcons.strokeRoundedCheckList,
          size: 52,
          color: context.sac.textTertiary,
        ),
        const SizedBox(height: 16),
        Text(
          'camporees.judge.no_primary_assignments'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.sac.text,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'camporees.judge.no_primary_assignments_hint'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.sac.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 20),
        SacButton.outline(
          text: 'common.retry'.tr(),
          icon: HugeIcons.strokeRoundedRefresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _ErrorAssignments extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorAssignments({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 96),
        HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          size: 48,
          color: context.sac.error,
        ),
        const SizedBox(height: 12),
        Text(
          'camporees.judge.assignments_error'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.sac.text,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.sac.textSecondary),
        ),
        const SizedBox(height: 20),
        SacButton.primary(
          text: 'common.retry'.tr(),
          icon: HugeIcons.strokeRoundedRefresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

List<List<CamporeeJudgeAssignment>> _groupJudgeAssignmentsByEvent(
  Iterable<CamporeeJudgeAssignment> assignments,
) {
  final groups = <int, List<CamporeeJudgeAssignment>>{};
  final order = <int>[];
  for (final assignment in assignments) {
    final existing = groups[assignment.eventId];
    if (existing == null) {
      order.add(assignment.eventId);
      groups[assignment.eventId] = [assignment];
    } else {
      existing.add(assignment);
    }
  }
  return [for (final id in order) groups[id]!];
}

String _eventTitleOf(CamporeeJudgeAssignment assignment) {
  final title = assignment.eventTitle?.trim();
  if (title != null && title.isNotEmpty) return title;
  return 'camporees.judge.event_fallback'.tr(
    namedArgs: {'eventId': '${assignment.eventId}'},
  );
}

String _clubLabelOf(CamporeeJudgeAssignment assignment) {
  if (assignment.displayClubLabel.isNotEmpty) {
    return assignment.displayClubLabel;
  }
  return 'camporees.judge.section_label'.tr(
    namedArgs: {'sectionId': '${assignment.clubSectionId}'},
  );
}

String? _clubSubtitleOf(
  CamporeeJudgeAssignment assignment, {
  required bool needsDisambiguation,
}) {
  final club = assignment.clubName?.trim();
  final section = assignment.sectionName?.trim();
  if (section != null &&
      section.isNotEmpty &&
      section.toLowerCase() != club?.toLowerCase()) {
    return section;
  }
  if (needsDisambiguation) {
    return 'camporees.judge.section_label'.tr(
      namedArgs: {'sectionId': '${assignment.clubSectionId}'},
    );
  }
  return null;
}

String _clubInitials(String label) {
  final words =
      label.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  if (words.isEmpty) return '—';
  if (words.length == 1) {
    final word = words.first;
    if (word.length <= 3) return word.toUpperCase();
    return String.fromCharCodes(word.runes.take(2)).toUpperCase();
  }
  return words
      .take(2)
      .map((word) => String.fromCharCodes(word.runes.take(1)))
      .join()
      .toUpperCase();
}
