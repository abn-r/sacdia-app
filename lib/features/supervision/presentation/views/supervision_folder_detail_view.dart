import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_folders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_folder_labels.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_summary_box.dart';

const double _kMaxContentWidth = 640;

/// One annual folder: where it stands (state panel), its points and its
/// sections grouped by what each one needs. A section opens its own screen
/// (`SupervisionFolderSectionView`), where an actor holding `folders.evaluate`
/// evaluates it and, with `folders.confirm_union`, confirms it.
///
/// «Cerrar carpeta» is the single fixed action, and only when the folder can
/// be closed.
class SupervisionFolderDetailView extends ConsumerStatefulWidget {
  const SupervisionFolderDetailView({super.key, required this.folderId});

  final String folderId;

  @override
  ConsumerState<SupervisionFolderDetailView> createState() =>
      _SupervisionFolderDetailViewState();
}

class _SupervisionFolderDetailViewState
    extends ConsumerState<SupervisionFolderDetailView> {
  bool _closing = false;

  String get _folderId => widget.folderId;

  Future<void> _refresh() async {
    ref.invalidate(supervisionFolderDetailProvider(_folderId));
    try {
      await ref.read(supervisionFolderDetailProvider(_folderId).future);
    } catch (_) {
      // The error state renders the failure.
    }
  }

  Future<void> _close() async {
    final confirmed = await SacDialog.show(
      context,
      title: 'supervision.folders.close_title'.tr(),
      content: 'supervision.folders.close_message'.tr(),
      confirmLabel: 'supervision.folders.close_action'.tr(),
      cancelLabel: 'common.cancel'.tr(),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _closing = true);
    final result =
        await ref.read(supervisionFolderActionsProvider).closeFolder(_folderId);
    if (!mounted) return;
    setState(() => _closing = false);
    SacSnackBar.show(
      context,
      result.ok
          ? 'supervision.folders.closed_toast'.tr()
          : supervisionErrorMessage(result.errorMessage),
      isSuccess: result.ok,
      isError: !result.ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canEvaluate = hasCapability(user, 'folders.evaluate');
    final canConfirm = hasCapability(user, 'folders.confirm_union');
    final folderAsync = ref.watch(supervisionFolderDetailProvider(_folderId));
    final folder = folderAsync.value;
    final closable =
        folder != null && canEvaluate && _isClosable(folder.status);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: folder == null || folder.clubName.trim().isEmpty
            ? 'supervision.folders.detail_title'.tr()
            : folder.clubName,
        subtitle: folder == null ? null : _placeLine(folder),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: SafeArea(
          top: false,
          child: folderAsync.when(
            skipLoadingOnReload: folderAsync.hasValue,
            loading: () => Padding(
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.fromLTRB(20, 24, 20, 0),
              ),
              child: const SacSkeletonList(
                itemCount: 6,
                leading: false,
                scrollable: false,
              ),
            ),
            error: (error, _) => isForbiddenFailure(error)
                ? ForbiddenView(
                    padding: SacTopBar.paddingBelowBar(
                      context,
                      const EdgeInsets.all(32),
                    ),
                  )
                : SacErrorState(
                    title: 'supervision.folders.detail_error_title'.tr(),
                    message: 'supervision.folders.error_message'.tr(),
                    onRetry: _refresh,
                    padding: SacTopBar.paddingBelowBar(
                      context,
                      const EdgeInsets.all(32),
                    ),
                  ),
            data: (folder) {
              final groups = _SectionGroups.of(
                folder,
                unionConfirms: canConfirm && folder.requiresUnionConfirmation,
              );
              return RefreshIndicator(
                color: SacAccent.of(context).color,
                edgeOffset: SacTopBar.frostedInset(context),
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.only(bottom: 32),
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _kMaxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: _FolderStatePanel(
                                folder: folder,
                                waiting: groups.toEvaluate.length,
                              ),
                            ),
                            _FolderPoints(folder: folder),
                            _SectionGroup(
                              folderId: _folderId,
                              labelKey: 'supervision.folders.group_to_evaluate',
                              sections: groups.toEvaluate,
                            ),
                            _SectionGroup(
                              folderId: _folderId,
                              labelKey: 'supervision.folders.group_evaluated',
                              sections: groups.evaluated,
                            ),
                            _SectionGroup(
                              folderId: _folderId,
                              labelKey: 'supervision.folders.group_unsent',
                              sections: groups.unsent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: closable
          ? SacFrostedFooter(
              note: 'supervision.folders.close_note'.tr(),
              child: SacButton.primary(
                text: 'supervision.folders.close_action'.tr(),
                icon: HugeIcons.strokeRoundedLock,
                isLoading: _closing,
                onPressed: _close,
              ),
            )
          : null,
    );
  }
}

/// The server closes a folder only from these two states.
bool _isClosable(SupervisionFolderStatus status) =>
    status == SupervisionFolderStatus.submitted ||
    status == SupervisionFolderStatus.evaluated;

String? _placeLine(SupervisionFolderDetail folder) {
  final line = [
    folder.clubTypeName,
    folder.yearLabel,
  ].where((part) => part.trim().isNotEmpty).join(' · ');
  return line.isEmpty ? null : line;
}

String _points(BuildContext context, int earned, int max) =>
    'supervision.folders.points_of'.tr(
      args: [supervisionCount(context, earned), supervisionCount(context, max)],
    );

// ── Sections by what they need ──────────────────────────────────────────────

/// The sections split in the three groups of the screen. What waits for the
/// Union is "to evaluate" only for an actor who confirms it; for everyone else
/// it is already evaluated.
class _SectionGroups {
  const _SectionGroups(this.toEvaluate, this.evaluated, this.unsent);

  factory _SectionGroups.of(
    SupervisionFolderDetail folder, {
    required bool unionConfirms,
  }) {
    final toEvaluate = <SupervisionFolderSection>[];
    final evaluated = <SupervisionFolderSection>[];
    final unsent = <SupervisionFolderSection>[];
    for (final section in folder.sections) {
      switch (section.status) {
        case SupervisionSectionStatus.submitted:
          toEvaluate.add(section);
        case SupervisionSectionStatus.preapprovedLf:
          (unionConfirms ? toEvaluate : evaluated).add(section);
        case SupervisionSectionStatus.validated:
        case SupervisionSectionStatus.rejected:
          evaluated.add(section);
        case SupervisionSectionStatus.pending:
        case SupervisionSectionStatus.unknown:
          unsent.add(section);
      }
    }
    return _SectionGroups(toEvaluate, evaluated, unsent);
  }

  final List<SupervisionFolderSection> toEvaluate;
  final List<SupervisionFolderSection> evaluated;
  final List<SupervisionFolderSection> unsent;
}

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({
    required this.folderId,
    required this.labelKey,
    required this.sections,
  });

  final String folderId;
  final String labelKey;
  final List<SupervisionFolderSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    return SacGroupedSection(
      label: labelKey.tr(),
      children: [
        for (final section in sections)
          _SectionRow(
            key: ValueKey(section.id),
            section: section,
            onTap: () => context.push(
              RouteNames.supervisionFolderSection(folderId, section.id),
            ),
          ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({super.key, required this.section, required this.onTap});

  final SupervisionFolderSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final max = 'supervision.folders.points_max'
        .tr(args: [supervisionCount(context, section.maxPoints)]);
    final String subtitle;
    switch (section.status) {
      case SupervisionSectionStatus.submitted:
        // What the evaluator is about to look at: the evidences.
        subtitle = section.evidences.isEmpty
            ? max
            : '$max · ${'supervision.folders.evidence_count'.plural(section.evidences.length)}';
      case SupervisionSectionStatus.pending:
      case SupervisionSectionStatus.unknown:
        subtitle = '${sectionStatusLabel(section.status)} · $max';
      case SupervisionSectionStatus.preapprovedLf:
      case SupervisionSectionStatus.validated:
      case SupervisionSectionStatus.rejected:
        subtitle = '${sectionStatusLabel(section.status)} · '
            '${section.earnedPoints == null ? max : _points(context, section.earnedPoints!, section.maxPoints)}';
    }
    return SacListRow(
      leading: SacListRowIcon(
        sectionStatusIcon(section.status),
        tone: sectionStatusTone(section.status),
      ),
      title: section.name,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

// ── State and points ────────────────────────────────────────────────────────

/// The folder state once, with the context of what waits. Tapping opens every
/// state of the folder, in order.
class _FolderStatePanel extends StatelessWidget {
  const _FolderStatePanel({required this.folder, required this.waiting});

  final SupervisionFolderDetail folder;

  /// Sections that wait for the actor.
  final int waiting;

  @override
  Widget build(BuildContext context) {
    final status = folder.status;
    final sent = folder.submittedAt == null
        ? null
        : 'supervision.folders.sent_on'
            .tr(args: [supervisionShortDate(context, folder.submittedAt!)]);
    final String? message = switch (status) {
      SupervisionFolderStatus.open => 'supervision.folders.state_open'.tr(),
      SupervisionFolderStatus.submitted ||
      SupervisionFolderStatus.underEvaluation =>
        [
          if (waiting > 0)
            'supervision.folders.state_waiting'
                .tr(args: ['$waiting', '${folder.sections.length}']),
          if (sent != null) sent,
        ].join(' '),
      SupervisionFolderStatus.evaluated =>
        'supervision.folders.state_evaluated'.tr(),
      SupervisionFolderStatus.closed => 'supervision.folders.state_closed'.tr(),
      SupervisionFolderStatus.unknown => null,
    };
    return SacStatePanel(
      key: const ValueKey('folder-state-panel'),
      style: folderStatusStyle(context, status),
      title: folderStatusLabel(status),
      message: message == null || message.isEmpty ? null : message,
      stepLabel: 'supervision.folders.see_all_states'.tr(),
      semanticsHint: 'supervision.folders.states_hint'.tr(),
      onTap: () => _showFolderStatesSheet(context, folder),
    );
  }
}

/// Open → sent → under evaluation → evaluated → closed, with the current one
/// highlighted and the dates the folder already has.
Future<void> _showFolderStatesSheet(
  BuildContext context,
  SupervisionFolderDetail folder,
) {
  const path = [
    SupervisionFolderStatus.open,
    SupervisionFolderStatus.submitted,
    SupervisionFolderStatus.underEvaluation,
    SupervisionFolderStatus.evaluated,
    SupervisionFolderStatus.closed,
  ];
  final current = path.indexOf(folder.status);
  String? date(DateTime? when) =>
      when == null ? null : supervisionShortDate(context, when);
  final details = <SupervisionFolderStatus, String?>{
    SupervisionFolderStatus.submitted: date(folder.submittedAt),
    SupervisionFolderStatus.evaluated: date(folder.evaluatedAt),
    SupervisionFolderStatus.closed: date(folder.closedAt),
  };
  return showSacStatesSheet(
    context,
    title: 'supervision.folders.states_title'.tr(),
    subtitle: folder.clubName.trim().isEmpty ? null : folder.clubName,
    steps: [
      for (var i = 0; i < path.length; i++)
        SacStateStep(
          kind: i < current
              ? SacStateKind.done
              : i == current
                  ? SacStateKind.current
                  : SacStateKind.pending,
          title: folderStatusLabel(path[i]),
          detail: i <= current ? details[path[i]] : null,
        ),
    ],
    kindLabels: SacStateKindLabels(
      done: 'supervision.folders.states_done'.tr(),
      current: 'supervision.folders.states_current'.tr(),
      rejected: 'supervision.folders.states_rejected'.tr(),
      pending: 'supervision.folders.states_pending'.tr(),
    ),
  );
}

/// Points of the folder in the grey box, with the bar split in what is
/// validated, what waits for the Union and what is still to evaluate.
class _FolderPoints extends StatelessWidget {
  const _FolderPoints({required this.folder});

  final SupervisionFolderDetail folder;

  @override
  Widget build(BuildContext context) {
    int validated = 0;
    int waitingUnion = 0;
    int toEvaluate = 0;
    for (final section in folder.sections) {
      switch (section.status) {
        case SupervisionSectionStatus.validated:
          validated += section.earnedPoints ?? 0;
        case SupervisionSectionStatus.preapprovedLf:
          waitingUnion += section.earnedPoints ?? 0;
        case SupervisionSectionStatus.submitted:
          toEvaluate += section.maxPoints;
        case SupervisionSectionStatus.rejected:
        case SupervisionSectionStatus.pending:
        case SupervisionSectionStatus.unknown:
          break;
      }
    }
    SacStatusSegment segment(SacTone tone, String key, int value) =>
        SacStatusSegment(
          count: value,
          color: SacTonePalette.of(context, tone).solid,
          label: key.tr(args: [supervisionCount(context, value)]),
        );
    return SupervisionSummaryBox(
      label: 'supervision.folders.points_box_title'.tr(),
      meta: 'supervision.folders.points_max'
          .tr(args: [supervisionCount(context, folder.totalMaxPoints)]),
      value: supervisionCount(context, folder.totalEarnedPoints),
      caption: supervisionPercent(folder.progressPercentage),
      segments: [
        segment(
            SacTone.success, 'supervision.folders.legend_validated', validated),
        segment(SacTone.info, 'supervision.folders.legend_waiting_union',
            waitingUnion),
        segment(SacTone.warning, 'supervision.folders.legend_to_evaluate',
            toEvaluate),
      ],
    );
  }
}
