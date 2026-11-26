import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
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
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_file_gallery.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_folders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_actions.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_decision_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_evaluate_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_folder_labels.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_quote.dart';

const double _kMaxContentWidth = 640;

/// Server limits.
const int _kNotesMaxLength = 500;
const int _kReviewerNoteMaxLength = 2000;

/// One section of an annual folder, on its own screen: what the club wrote,
/// the evidences (large, they are what the evaluation rests on) and the notes
/// of the review.
///
/// The one action of the screen is fixed at the bottom: «Evaluar sección» (or
/// «Evaluar de nuevo»), the Union's «Confirmar {n} pts» with «Rechazar
/// sección» under it, or «Reabrir sección» once it is decided. Actions need
/// `folders.evaluate`; confirming needs `folders.confirm_union`.
class SupervisionFolderSectionView extends ConsumerStatefulWidget {
  const SupervisionFolderSectionView({
    super.key,
    required this.folderId,
    required this.sectionId,
  });

  final String folderId;
  final String sectionId;

  @override
  ConsumerState<SupervisionFolderSectionView> createState() =>
      _SupervisionFolderSectionViewState();
}

class _SupervisionFolderSectionViewState
    extends ConsumerState<SupervisionFolderSectionView> {
  bool _busy = false;
  String? _error;

  SupervisionFolderActions get _actions =>
      ref.read(supervisionFolderActionsProvider);

  Future<void> _refresh() async {
    ref.invalidate(supervisionFolderDetailProvider(widget.folderId));
    try {
      await ref.read(supervisionFolderDetailProvider(widget.folderId).future);
    } catch (_) {
      // The error state renders the failure.
    }
  }

  /// Runs a decision on the section. On success the screen goes back to the
  /// folder, which reloads with the new state.
  Future<void> _run(
    Future<SupervisionFolderActionResult> Function() action,
    String successKey,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await action();
    if (!mounted) return;
    if (result.ok) {
      SacSnackBar.show(context, successKey.tr(), isSuccess: true);
      if (context.canPop()) context.pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = _errorText(result);
    });
  }

  String _errorText(SupervisionFolderActionResult result) {
    final key = switch (result.errorCode) {
      'ANNUAL_FOLDER_UNION_ROLE_REQUIRED' =>
        'supervision.folders.error_union_role',
      'ANNUAL_FOLDER_EARNED_POINTS_EXCEED_MAX' =>
        'supervision.folders.error_points_exceed',
      'ANNUAL_FOLDER_EVIDENCE_TERRITORY_DENIED' ||
      'ANNUAL_FOLDER_FOLDER_ACCESS_DENIED' =>
        'supervision.folders.error_territory',
      'ANNUAL_FOLDER_STATUS_INVALID_FOR_EVALUATE' ||
      'ANNUAL_FOLDER_STATUS_INVALID_FOR_REOPEN' ||
      'ANNUAL_FOLDER_SECTION_TERMINAL' ||
      'ANNUAL_FOLDER_SECTION_NOT_PREAPPROVED' ||
      'ANNUAL_FOLDER_STATUS_CONFLICT' =>
        'supervision.folders.error_stale',
      _ => null,
    };
    return key?.tr() ?? supervisionErrorMessage(result.errorMessage);
  }

  Future<void> _evaluate(SupervisionFolderSection section) async {
    final evaluation = await showSupervisionEvaluateSheet(context, section);
    if (evaluation == null || !mounted) return;
    await _run(
      () => _actions.evaluateSection(
        widget.folderId,
        section.id,
        earnedPoints: evaluation.points,
        notes: evaluation.notes,
      ),
      'supervision.folders.evaluated_toast',
    );
  }

  Future<void> _confirmUnion(
    SupervisionFolderSection section, {
    required bool approve,
  }) async {
    final notes = await showSupervisionDecisionSheet(
      context: context,
      title: (approve
              ? 'supervision.folders.confirm_title'
              : 'supervision.folders.override_title')
          .tr(),
      message: section.name,
      fieldLabel: 'supervision.folders.notes_label'.tr(),
      confirmLabel: (approve
              ? 'supervision.folders.confirm_action'
              : 'coordinator.actions.reject')
          .tr(),
      maxLength: _kNotesMaxLength,
      destructive: !approve,
    );
    if (notes == null || !mounted) return;
    await _run(
      () => _actions.confirmUnion(
        widget.folderId,
        section.id,
        approve: approve,
        notes: notes,
      ),
      approve
          ? 'supervision.folders.confirmed_toast'
          : 'supervision.folders.overridden_toast',
    );
  }

  Future<void> _reopen(SupervisionFolderSection section) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'supervision.folders.reopen_title'.tr(),
      content: 'supervision.folders.reopen_message'.tr(),
      confirmLabel: 'supervision.folders.reopen_action'.tr(),
      cancelLabel: 'common.cancel'.tr(),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _actions.reopenSection(widget.folderId, section.id),
      'supervision.folders.reopened_toast',
    );
  }

  /// A note is saved without leaving the screen: there may be several.
  Future<void> _editNote(SupervisionFolderEvidence evidence) async {
    final note = await showSupervisionDecisionSheet(
      context: context,
      title: 'supervision.folders.note_title'.tr(),
      message: evidence.fileName,
      fieldLabel: 'supervision.folders.note_label'.tr(),
      fieldHint: 'supervision.folders.note_hint'.tr(),
      confirmLabel: 'common.save'.tr(),
      maxLength: _kReviewerNoteMaxLength,
      destructive: false,
      initialText: evidence.reviewerNote,
    );
    if (note == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _actions.saveReviewerNote(
      widget.folderId,
      evidence.id,
      note,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.ok ? null : _errorText(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canEvaluate = hasCapability(user, 'folders.evaluate');
    final canConfirm = hasCapability(user, 'folders.confirm_union');
    final folderAsync =
        ref.watch(supervisionFolderDetailProvider(widget.folderId));
    final folder = folderAsync.value;
    SupervisionFolderSection? section;
    for (final candidate
        in folder?.sections ?? const <SupervisionFolderSection>[]) {
      if (candidate.id == widget.sectionId) section = candidate;
    }

    Widget? footer;
    if (folder != null && section != null) {
      footer = _footer(
        folder,
        section,
        canEvaluate: canEvaluate,
        canConfirm: canConfirm,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: section?.name ?? 'supervision.folders.section_title'.tr(),
        subtitle: section == null
            ? null
            : [
                if (folder!.clubName.trim().isNotEmpty) folder.clubName,
                sectionStatusLabel(section.status),
              ].join(' · '),
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
                itemCount: 4,
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
              if (section == null) {
                // The folder reloaded without this section.
                return SacErrorState(
                  title: 'supervision.folders.section_missing_title'.tr(),
                  message: 'supervision.folders.error_stale'.tr(),
                  onRetry: _refresh,
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.all(32),
                  ),
                );
              }
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
                        child: _SectionBody(
                          section: section,
                          unionConfirm: _isUnionConfirm(
                            folder,
                            section,
                            canConfirm: canConfirm,
                          ),
                          onEditNote: _isOpen(folder) && canEvaluate && !_busy
                              ? _editNote
                              : null,
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
      bottomNavigationBar: (footer == null && _error == null)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  ColoredBox(
                    color: c.canvas,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SupervisionInlineError(message: _error!),
                    ),
                  ),
                if (footer != null) footer,
              ],
            ),
    );
  }

  bool _isOpen(SupervisionFolderDetail folder) =>
      folder.status != SupervisionFolderStatus.closed;

  /// The Union decides on what the local field already evaluated.
  bool _isUnionConfirm(
    SupervisionFolderDetail folder,
    SupervisionFolderSection section, {
    required bool canConfirm,
  }) =>
      _isOpen(folder) &&
      canConfirm &&
      folder.requiresUnionConfirmation &&
      section.status == SupervisionSectionStatus.preapprovedLf;

  /// The fixed action for this section and this actor, or null when there is
  /// none (folder closed, no capability, nothing to decide).
  Widget? _footer(
    SupervisionFolderDetail folder,
    SupervisionFolderSection section, {
    required bool canEvaluate,
    required bool canConfirm,
  }) {
    if (!_isOpen(folder)) return null;
    final status = section.status;
    final decided = status == SupervisionSectionStatus.validated ||
        status == SupervisionSectionStatus.rejected;
    final waiting = status == SupervisionSectionStatus.submitted ||
        status == SupervisionSectionStatus.preapprovedLf;

    if (_isUnionConfirm(folder, section, canConfirm: canConfirm)) {
      return SacFrostedFooter(
        child: SupervisionStackedActions(
          primaryLabel: 'supervision.folders.confirm_points'.tr(
            args: [supervisionCount(context, section.earnedPoints ?? 0)],
          ),
          primaryIcon: HugeIcons.strokeRoundedTick02,
          onPrimary: () => _confirmUnion(section, approve: true),
          secondaryLabel: 'supervision.folders.override_title'.tr(),
          secondaryIcon: HugeIcons.strokeRoundedCancel01,
          onSecondary: () => _confirmUnion(section, approve: false),
          isLoading: _busy,
        ),
      );
    }
    if (canEvaluate && waiting) {
      return SacFrostedFooter(
        child: SacButton.primary(
          text: (status == SupervisionSectionStatus.preapprovedLf
                  ? 'supervision.folders.evaluate_again_action'
                  : 'supervision.folders.evaluate_action')
              .tr(),
          icon: HugeIcons.strokeRoundedTick02,
          isLoading: _busy,
          labelMaxLines: 2,
          onPressed: () => _evaluate(section),
        ),
      );
    }
    if (canEvaluate && decided) {
      return SacFrostedFooter(
        child: SacButton.outline(
          text: 'supervision.folders.reopen_action'.tr(),
          isLoading: _busy,
          labelMaxLines: 2,
          onPressed: () => _reopen(section),
        ),
      );
    }
    return null;
  }
}

// ── Body ────────────────────────────────────────────────────────────────────

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.unionConfirm,
    required this.onEditNote,
  });

  final SupervisionFolderSection section;

  /// The Union is about to confirm what the local field evaluated.
  final bool unionConfirm;

  /// Null when the actor cannot write reviewer notes.
  final ValueChanged<SupervisionFolderEvidence>? onEditNote;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.folders.$key'.tr(),
          value: value,
        );

    final evaluationRows = [
      if (section.earnedPoints != null)
        row(
          'points',
          'supervision.folders.points_of'.tr(args: [
            supervisionCount(context, section.earnedPoints!),
            supervisionCount(context, section.maxPoints),
          ]),
        ),
      if (_has(section.evaluationNotes))
        row('evaluation_notes', section.evaluationNotes!),
      if (_has(section.lfApproverName))
        row('evaluated_by', section.lfApproverName!),
      if (section.lfApprovedAt != null)
        row(
          'evaluated_at',
          supervisionShortDate(context, section.lfApprovedAt!),
        ),
      if (_has(section.unionApproverName))
        row('union_by', section.unionApproverName!),
      if (section.unionApprovedAt != null)
        row(
          'union_at',
          supervisionShortDate(context, section.unionApprovedAt!),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unionConfirm) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _LocalFieldPanel(section: section),
          ),
          if (_has(section.evaluationNotes))
            SupervisionQuote(
              label: 'supervision.folders.local_field_note'.tr(),
              text: section.evaluationNotes!.trim(),
              icon: HugeIcons.strokeRoundedBubbleChat,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            ),
        ],
        if (_has(section.description))
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              section.description!,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                height: 1.45,
                color: c.textSecondary,
              ),
            ),
          ),
        if (!unionConfirm && evaluationRows.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.folders.evaluation_title'.tr(),
            dividerIndent: 16,
            action: const SizedBox.shrink(),
            children: evaluationRows,
          ),
        _Eyebrow(
          label: 'supervision.folders.evidences_title'.tr(),
          count: section.evidences.length,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EvidenceFileGallery(
            files: [
              for (final evidence in section.evidences)
                EvidenceFile(
                  id: evidence.id,
                  url: evidence.fileUrl,
                  name: evidence.fileName,
                ),
            ],
          ),
        ),
        if (section.evidences.isNotEmpty)
          SacGroupedSection(
            label: 'supervision.folders.notes_title'.tr(),
            children: [
              for (final evidence in section.evidences)
                SacListRow(
                  key: ValueKey(evidence.id),
                  leading: SacListRowIcon(
                    _isImageName(evidence.fileName)
                        ? HugeIcons.strokeRoundedImage01
                        : HugeIcons.strokeRoundedFile01,
                    tone: SacTone.muted,
                  ),
                  title: evidence.fileName,
                  subtitle: _has(evidence.reviewerNote)
                      ? evidence.reviewerNote
                      : 'supervision.folders.note_empty'.tr(),
                  subtitleColor:
                      _has(evidence.reviewerNote) ? c.text : c.textTertiary,
                  onTap:
                      onEditNote == null ? null : () => onEditNote!(evidence),
                ),
            ],
          ),
      ],
    );
  }
}

/// What the local field decided, read-only: the Union confirms or overrides
/// it from the footer.
class _LocalFieldPanel extends StatelessWidget {
  const _LocalFieldPanel({required this.section});

  final SupervisionFolderSection section;

  @override
  Widget build(BuildContext context) {
    final who = section.lfApproverName?.trim();
    final when = section.lfApprovedAt;
    final points = section.earnedPoints;
    final message = [
      if (who != null && who.isNotEmpty) who,
      if (when != null) supervisionShortDate(context, when),
      if (points != null)
        'supervision.folders.points_of'.tr(args: [
          supervisionCount(context, points),
          supervisionCount(context, section.maxPoints),
        ]),
    ].join(' · ');
    return SacStatePanel(
      key: const ValueKey('section-local-field-panel'),
      style: SacStatusStyle.of(
        context,
        SacStatusKind.review,
        label: 'supervision.folders.local_field_evaluated'.tr(),
        icon: HugeIcons.strokeRoundedClock01,
      ),
      title: 'supervision.folders.local_field_evaluated'.tr(),
      message: message.isEmpty ? null : message,
    );
  }
}

/// «EVIDENCIAS 5»: the label of a block that is not a list of rows.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = TextStyle(
      fontSize: SacFontSize.labelSmall,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: c.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: Text(label.toUpperCase(), style: style)),
            Text('$count', style: style),
          ],
        ),
      ),
    );
  }
}

bool _has(String? value) => value != null && value.trim().isNotEmpty;

bool _isImageName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic');
}
