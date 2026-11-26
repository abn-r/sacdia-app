import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/approval_action_buttons.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_file_gallery.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_folders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_decision_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_folder_labels.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';

const double _kMaxContentWidth = 640;

/// Server limits.
const int _kNotesMaxLength = 500;
const int _kReviewerNoteMaxLength = 2000;

/// One annual folder: where it stands and its sections. A section opens in a
/// sheet with its evidences and, for an actor holding `folders.evaluate`, the
/// evaluation; the Union confirmation needs `folders.confirm_union`.
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
            data: (folder) => RefreshIndicator(
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
                          _FolderSummary(folder: folder),
                          _SectionsList(
                            folder: folder,
                            onOpen: (section) => _showSectionSheet(
                              context,
                              folderId: _folderId,
                              sectionId: section.id,
                              canEvaluate: canEvaluate,
                              canConfirm: canConfirm,
                            ),
                          ),
                          if (canEvaluate && _isClosable(folder.status))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                              child: SacButton.outline(
                                text: 'supervision.folders.close_action'.tr(),
                                isLoading: _closing,
                                onPressed: _close,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

// ── Summary ─────────────────────────────────────────────────────────────────

class _FolderSummary extends StatelessWidget {
  const _FolderSummary({required this.folder});

  final SupervisionFolderDetail folder;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final percent = supervisionPercent(folder.progressPercentage);
    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.folders.$key'.tr(),
          value: value,
        );

    return SacGroupedSection(
      label: 'supervision.folders.summary_title'.tr(),
      dividerIndent: 16,
      // A count of rows says nothing here.
      action: const SizedBox.shrink(),
      children: [
        row('status', folderStatusLabel(folder.status)),
        row(
          'points',
          _points(context, folder.totalEarnedPoints, folder.totalMaxPoints),
        ),
        row('progress', percent),
        if (folder.localFieldName.trim().isNotEmpty)
          row('local_field', folder.localFieldName),
        if (folder.templateName.trim().isNotEmpty)
          row('template', folder.templateName),
        if (folder.submittedAt != null)
          row(
            'submitted_at',
            intl.DateFormat.yMMMd(locale).format(folder.submittedAt!),
          ),
      ],
    );
  }
}

// ── Sections ────────────────────────────────────────────────────────────────

class _SectionsList extends StatelessWidget {
  const _SectionsList({required this.folder, required this.onOpen});

  final SupervisionFolderDetail folder;
  final ValueChanged<SupervisionFolderSection> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacGroupedSection(
      label: 'supervision.folders.sections_title'.tr(),
      children: [
        for (final section in folder.sections)
          SacListRow(
            leading: SacListRowIcon(
              sectionStatusIcon(section.status),
              destructive: section.status == SupervisionSectionStatus.rejected,
            ),
            title: section.name,
            subtitleSpans: [
              TextSpan(
                text: sectionStatusLabel(section.status),
                style: TextStyle(
                  color: _needsAttention(section.status) ? c.text : null,
                  fontWeight:
                      _needsAttention(section.status) ? FontWeight.w600 : null,
                ),
              ),
              TextSpan(text: ' · ${_sectionPoints(context, section)}'),
            ],
            onTap: () => onOpen(section),
          ),
      ],
    );
  }
}

/// A section someone still has to decide on.
bool _needsAttention(SupervisionSectionStatus status) =>
    status == SupervisionSectionStatus.submitted ||
    status == SupervisionSectionStatus.preapprovedLf;

String _sectionPoints(BuildContext context, SupervisionFolderSection section) =>
    section.earnedPoints == null
        ? 'supervision.folders.points_max'
            .tr(args: [supervisionCount(context, section.maxPoints)])
        : _points(context, section.earnedPoints!, section.maxPoints);

// ── Section sheet ───────────────────────────────────────────────────────────

Future<void> _showSectionSheet(
  BuildContext context, {
  required String folderId,
  required String sectionId,
  required bool canEvaluate,
  required bool canConfirm,
}) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SectionSheet(
      folderId: folderId,
      sectionId: sectionId,
      canEvaluate: canEvaluate,
      canConfirm: canConfirm,
    ),
  );
}

class _SectionSheet extends ConsumerStatefulWidget {
  const _SectionSheet({
    required this.folderId,
    required this.sectionId,
    required this.canEvaluate,
    required this.canConfirm,
  });

  final String folderId;
  final String sectionId;
  final bool canEvaluate;
  final bool canConfirm;

  @override
  ConsumerState<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends ConsumerState<_SectionSheet> {
  bool _busy = false;
  String? _error;

  SupervisionFolderActions get _actions =>
      ref.read(supervisionFolderActionsProvider);

  /// Runs a decision on the section. The sheet closes on success: the folder
  /// behind it reloads with the new state.
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
      Navigator.of(context).pop();
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
    final evaluation = await showSacSheet<_Evaluation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EvaluateSheet(section: section),
    );
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

  /// A note is saved without closing the sheet: there may be several.
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
    final folder =
        ref.watch(supervisionFolderDetailProvider(widget.folderId)).value;
    SupervisionFolderSection? section;
    for (final candidate
        in folder?.sections ?? const <SupervisionFolderSection>[]) {
      if (candidate.id == widget.sectionId) section = candidate;
    }
    if (folder == null || section == null) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: SacSkeletonList(
            itemCount: 3,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    }
    final current = section;
    final open = folder.status != SupervisionFolderStatus.closed;
    final preapproved =
        current.status == SupervisionSectionStatus.preapprovedLf;
    final decided = current.status == SupervisionSectionStatus.validated ||
        current.status == SupervisionSectionStatus.rejected;

    // The Union decides on what the field already evaluated; everyone else
    // with the capability evaluates what the club submitted.
    final Widget? actions;
    if (open &&
        widget.canConfirm &&
        folder.requiresUnionConfirmation &&
        preapproved) {
      actions = ApprovalActionBar(
        isLoading: _busy,
        approveLabel: 'supervision.folders.confirm_action'.tr(),
        onApprove: () => _confirmUnion(current, approve: true),
        onReject: () => _confirmUnion(current, approve: false),
      );
    } else if (open && widget.canEvaluate && _needsAttention(current.status)) {
      actions = _SheetAction(
        child: SacButton.primary(
          text: (preapproved
                  ? 'supervision.folders.evaluate_again_action'
                  : 'supervision.folders.evaluate_action')
              .tr(),
          isLoading: _busy,
          labelMaxLines: 2,
          onPressed: () => _evaluate(current),
        ),
      );
    } else if (open && widget.canEvaluate && decided) {
      actions = _SheetAction(
        child: SacButton.outline(
          text: 'supervision.folders.reopen_action'.tr(),
          isLoading: _busy,
          labelMaxLines: 2,
          onPressed: () => _reopen(current),
        ),
      );
    } else {
      actions = null;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: current.name,
            subtitle:
                '${sectionStatusLabel(current.status)} · ${_sectionPoints(context, current)}',
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: _SectionBody(
                section: current,
                onEditNote:
                    open && widget.canEvaluate && !_busy ? _editNote : null,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.35,
                    color: c.error,
                  ),
                ),
              ),
            ),
          actions ?? const SafeArea(top: false, child: SizedBox(height: 4)),
        ],
      ),
    );
  }
}

/// The single action of a sheet, clear of the home indicator.
class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: child,
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section, required this.onEditNote});

  final SupervisionFolderSection section;

  /// Null when the actor cannot write reviewer notes.
  final ValueChanged<SupervisionFolderEvidence>? onEditNote;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    String date(DateTime when) => intl.DateFormat.yMMMd(locale).format(when);
    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.folders.$key'.tr(),
          value: value,
        );
    bool has(String? value) => value != null && value.trim().isNotEmpty;

    final evaluationRows = [
      if (section.earnedPoints != null)
        row(
          'points',
          _points(context, section.earnedPoints!, section.maxPoints),
        ),
      if (has(section.evaluationNotes))
        row('evaluation_notes', section.evaluationNotes!),
      if (has(section.lfApproverName))
        row('evaluated_by', section.lfApproverName!),
      if (section.lfApprovedAt != null)
        row('evaluated_at', date(section.lfApprovedAt!)),
      if (has(section.unionApproverName))
        row('union_by', section.unionApproverName!),
      if (section.unionApprovedAt != null)
        row('union_at', date(section.unionApprovedAt!)),
    ];

    Widget group(String key, List<Widget> rows, {double indent = 16}) =>
        SacGroupedSection(
          label: 'supervision.folders.$key'.tr(),
          dividerIndent: indent,
          // A count of rows says nothing here.
          action: const SizedBox.shrink(),
          children: rows,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (has(section.description))
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Text(
              section.description!,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                height: 1.45,
                color: c.textSecondary,
              ),
            ),
          ),
        if (evaluationRows.isNotEmpty)
          group('evaluation_title', evaluationRows),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Semantics(
            header: true,
            child: Text(
              'supervision.folders.evidences_title'.tr().toUpperCase(),
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: c.textTertiary,
              ),
            ),
          ),
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
          group(
            'notes_title',
            indent: 58,
            [
              for (final evidence in section.evidences)
                SacListRow(
                  leading: const SacListRowIcon(HugeIcons.strokeRoundedFile01),
                  title: evidence.fileName,
                  subtitle: has(evidence.reviewerNote)
                      ? evidence.reviewerNote
                      : 'supervision.folders.note_empty'.tr(),
                  subtitleColor:
                      has(evidence.reviewerNote) ? c.text : c.textTertiary,
                  onTap:
                      onEditNote == null ? null : () => onEditNote!(evidence),
                ),
            ],
          ),
      ],
    );
  }
}

// ── Evaluate sheet ──────────────────────────────────────────────────────────

class _Evaluation {
  const _Evaluation(this.points, this.notes);

  final int points;
  final String notes;
}

/// Points earned by the section (0 to its maximum) and an optional note.
class _EvaluateSheet extends StatefulWidget {
  const _EvaluateSheet({required this.section});

  final SupervisionFolderSection section;

  @override
  State<_EvaluateSheet> createState() => _EvaluateSheetState();
}

class _EvaluateSheetState extends State<_EvaluateSheet> {
  late final _pointsCtrl = TextEditingController(
    text: widget.section.earnedPoints?.toString() ?? '',
  );
  late final _notesCtrl = TextEditingController(
    text: widget.section.evaluationNotes ?? '',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pointsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _validatePoints(String? value) {
    final points = int.tryParse((value ?? '').trim());
    final max = widget.section.maxPoints;
    if (points == null || points < 0 || points > max) {
      return 'supervision.folders.points_invalid'.tr(args: ['$max']);
    }
    return null;
  }

  void _confirm() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      _Evaluation(int.parse(_pointsCtrl.text.trim()), _notesCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.section.maxPoints;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(
                title: 'supervision.folders.evaluate_title'.tr(),
                subtitle: widget.section.name,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SacTextField(
                        controller: _pointsCtrl,
                        label: 'supervision.folders.points_label'.tr(),
                        helperText:
                            'supervision.folders.points_max'.tr(args: ['$max']),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textInputAction: TextInputAction.next,
                        validator: _validatePoints,
                      ),
                      const SizedBox(height: 16),
                      SacTextField(
                        controller: _notesCtrl,
                        label: 'supervision.folders.notes_label'.tr(),
                        maxLines: 3,
                        maxLength: _kNotesMaxLength,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SacButton.outline(
                              text: 'common.cancel'.tr(),
                              labelMaxLines: 2,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SacButton.primary(
                              text: 'supervision.folders.evaluate_action'.tr(),
                              labelMaxLines: 2,
                              onPressed: _confirm,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
