import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_official_score.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_score_breakdown.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_score_format.dart';

import '../providers/camporees_providers.dart';

/// «awarded / max» using the shared score formatter.
String camporeeScoreFraction(CamporeeOfficialScore score) =>
    '${formatCamporeeScoreNumber(score.totalAwarded)} / '
    '${formatCamporeeScoreNumber(score.totalMax)}';

const _tabular = [FontFeature.tabularFigures()];

/// Per-event scores in the event detail.
///
/// Club roles (`own`) see their section's rubric breakdown and the judge's
/// comments inline; admins and pastors see every section and open the same
/// detail in a bottom sheet.
class CamporeeEventScoresGroup extends ConsumerWidget {
  final int camporeeId;
  final CamporeeEvent event;

  const CamporeeEventScoresGroup({
    super.key,
    required this.camporeeId,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!event.isScored) return const SizedBox.shrink();
    final c = context.sac;
    final async = ref.watch(camporeeScoreBreakdownProvider(camporeeId));

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: async.when(
        loading: () => SacSettingsGroup(
          key: const Key('camporee-event-scores'),
          title: 'camporees.detail.score_all_title'.tr().toUpperCase(),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: SacLoadingSmall()),
            ),
          ],
        ),
        error: (_, __) => SacSettingsGroup(
          key: const Key('camporee-event-scores'),
          title: 'camporees.detail.score_all_title'.tr().toUpperCase(),
          children: [
            _ScoreMessageRow(
              icon: HugeIcons.strokeRoundedAlert02,
              iconColor: c.warning,
              text: 'camporees.detail.score_error'.tr(),
              trailing: SacButton.text(
                text: 'camporees.section_registration.retry'.tr(),
                onPressed: () =>
                    ref.invalidate(camporeeScoreBreakdownProvider(camporeeId)),
              ),
            ),
          ],
        ),
        data: (breakdown) {
          final entries = breakdown.entriesForEvent(event.camporeeEventId);
          return breakdown.isOwn
              ? _OwnScores(entries: entries)
              : _AllScores(entries: entries);
        },
      ),
    );
  }
}

class _OwnScores extends StatelessWidget {
  final List<CamporeeScoreBreakdownEntry> entries;

  const _OwnScores({required this.entries});

  @override
  Widget build(BuildContext context) {
    final title = 'camporees.detail.score_own_title'.tr().toUpperCase();
    if (entries.isEmpty) {
      return SacSettingsGroup(
        key: const Key('camporee-event-scores'),
        title: title,
        children: [
          _ScoreMessageRow(
            icon: HugeIcons.strokeRoundedAward01,
            iconColor: context.sac.textTertiary,
            text: 'camporees.detail.score_own_empty'.tr(),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          SacSettingsGroup(
            key: i == 0 ? const Key('camporee-event-scores') : null,
            title: title,
            children: camporeeScoreDetailRows(
              entries[i].result.score,
              totalLabel: entries.length > 1
                  ? _sectionName(entries[i].section)
                  : 'camporees.detail.score_total'.tr(),
              ownView: true,
            ),
          ),
          CamporeeScoreEvaluatorFooter(score: entries[i].result.score),
        ],
      ],
    );
  }
}

class _AllScores extends StatelessWidget {
  final List<CamporeeScoreBreakdownEntry> entries;

  const _AllScores({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return SacSettingsGroup(
      key: const Key('camporee-event-scores'),
      title: '${'camporees.detail.score_all_title'.tr().toUpperCase()}'
          ' · ${entries.length}',
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SacSettingsDivider(),
          _SectionScoreRow(
            entry: entries[i],
            onTap: () => _showScoreSheet(context, entries[i]),
          ),
        ],
      ],
    );
  }
}

String _clubName(CamporeeScoreBreakdownSection section) {
  final name = section.clubName?.trim();
  return name != null && name.isNotEmpty
      ? name
      : 'camporees.detail.score_unknown_club'.tr();
}

String _sectionName(CamporeeScoreBreakdownSection section) {
  final name = section.sectionName?.trim();
  return name != null && name.isNotEmpty
      ? name
      : 'camporees.detail.leaderboard_section_fallback'
          .tr(namedArgs: {'id': '${section.clubSectionId}'});
}

class _SectionScoreRow extends StatelessWidget {
  final CamporeeScoreBreakdownEntry entry;
  final VoidCallback onTap;

  const _SectionScoreRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final score = entry.result.score;
    return MergeSemantics(
      child: SacInkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _clubName(entry.section),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      Text(
                        _sectionName(entry.section),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  score.isNoShow
                      ? 'camporees.detail.score_no_show'.tr()
                      : camporeeScoreFraction(score),
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    fontWeight: FontWeight.w700,
                    color: score.isNoShow ? c.textSecondary : c.text,
                    fontFeatures: _tabular,
                  ),
                ),
                const SizedBox(width: 6),
                ExcludeSemantics(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: c.textTertiary,
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

/// Rows of one result: total, a row per rubric (with its comment) and the
/// general judge comment. Shared by the inline own view and the sheet.
List<Widget> camporeeScoreDetailRows(
  CamporeeOfficialScore score, {
  required String totalLabel,
  required bool ownView,
}) {
  final rows = <Widget>[];
  if (score.isNoShow) {
    rows.add(
      _ScoreMessageRow(
        icon: HugeIcons.strokeRoundedAlert02,
        text: ownView
            ? 'camporees.detail.score_own_no_show'.tr()
            : 'camporees.detail.score_no_show'.tr(),
      ),
    );
  } else {
    rows.add(
      _ScoreLineRow(
        title: totalLabel,
        points: camporeeScoreFraction(score),
        emphasized: true,
      ),
    );
    for (final item in score.items) {
      rows.add(
        _ScoreLineRow(
          title: item.title,
          points: '${formatCamporeeScoreNumber(item.awardedPoints)} / '
              '${formatCamporeeScoreNumber(item.maxPoints)}',
          comment: item.notes,
        ),
      );
    }
  }
  final notes = score.notes?.trim();
  if (notes != null && notes.isNotEmpty) {
    rows.add(
      _ScoreCommentRow(
        label: 'camporees.detail.score_judge_comment'.tr(),
        text: notes,
      ),
    );
  }
  return [
    for (var i = 0; i < rows.length; i++) ...[
      if (i > 0) const SacSettingsDivider(),
      rows[i],
    ],
  ];
}

/// «Evaluó Ana Ruiz · 1 nov 2026», or nothing when the judge is unknown.
class CamporeeScoreEvaluatorFooter extends StatelessWidget {
  final CamporeeOfficialScore score;

  const CamporeeScoreEvaluatorFooter({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final name = score.evaluatorName.trim();
    if (name.isEmpty) return const SizedBox.shrink();
    final submitted = score.submittedAt;
    final text = submitted == null
        ? 'camporees.detail.score_evaluated_by_no_date'
            .tr(namedArgs: {'name': name})
        : 'camporees.detail.score_evaluated_by'.tr(
            namedArgs: {
              'name': name,
              'date': SacDateFormatter.dateShort(submitted)
            },
          );
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

class _ScoreLineRow extends StatelessWidget {
  final String title;
  final String points;
  final String? comment;
  final bool emphasized;

  const _ScoreLineRow({
    required this.title,
    required this.points,
    this.comment,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final note = comment?.trim();
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: emphasized
                            ? SacFontSize.titleMedium
                            : SacFontSize.bodyMedium,
                        fontWeight:
                            emphasized ? FontWeight.w700 : FontWeight.w600,
                        color: c.text,
                        height: 1.3,
                      ),
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                points,
                style: TextStyle(
                  fontSize: emphasized
                      ? SacFontSize.titleMedium
                      : SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCommentRow extends StatelessWidget {
  final String label;
  final String text;

  const _ScoreCommentRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: c.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.text,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreMessageRow extends StatelessWidget {
  final HugeIconData icon;
  final Color? iconColor;
  final String text;
  final Widget? trailing;

  const _ScoreMessageRow({
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

/// Detail of one section's result for admins and pastors.
Future<void> _showScoreSheet(
  BuildContext context,
  CamporeeScoreBreakdownEntry entry,
) {
  HapticFeedback.selectionClick();
  final score = entry.result.score;
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.sac.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusXL),
      ),
    ),
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: _clubName(entry.section),
            subtitle: _sectionName(entry.section),
            showClose: true,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SacSettingsGroup(
                    key: const Key('camporee-event-score-sheet'),
                    children: camporeeScoreDetailRows(
                      score,
                      totalLabel: 'camporees.detail.score_total'.tr(),
                      ownView: false,
                    ),
                  ),
                  CamporeeScoreEvaluatorFooter(score: score),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
