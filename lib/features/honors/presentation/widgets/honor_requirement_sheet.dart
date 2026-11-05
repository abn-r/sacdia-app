import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_submission_readiness.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_requirement_evidence.dart';

/// Focused sheet that works ONE requirement without sub-items: its text,
/// "Tu respuesta", its evidence (when it asks for it) and the folded
/// reference.
///
/// Saving with an answer marks it done; saving it emptied marks it pending.
/// "Guardar" stays off until the answer changes. In the same request it
/// brings the evidence-carrying parents under [root] in step (see
/// [evidenceParentUpdates]). Closing with an unsaved answer asks first.
/// Evidence uploads happen right away and are not part of the edit. With
/// [enabled] false (under review) it is read-only.
class HonorRequirementSheet extends ConsumerStatefulWidget {
  const HonorRequirementSheet({
    super.key,
    required this.honorId,
    required this.requirement,
    required this.title,
    required this.paintColor,
    required this.bandColor,
    required this.enabled,
    this.contextLine,
    this.root,
  });

  final int honorId;
  final HonorRequirement requirement;

  /// "Requisito 3", "Inciso c".
  final String title;

  /// Line above the text that places a sub-item ("Requisito 4 · Elige 3").
  final String? contextLine;

  /// Top-level requirement this one belongs to, when it is a sub-item.
  final HonorRequirement? root;

  /// Category paint (evidence tile).
  final Color paintColor;

  /// Darkened category color that holds white text (the save button).
  final Color bandColor;
  final bool enabled;

  static Future<void> show(
    BuildContext context, {
    required int honorId,
    required HonorRequirement requirement,
    required String title,
    required Color paintColor,
    required Color bandColor,
    required bool enabled,
    String? contextLine,
    HonorRequirement? root,
  }) {
    return showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // A drag would close the route without asking about unsaved edits.
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (_) => HonorRequirementSheet(
        honorId: honorId,
        requirement: requirement,
        title: title,
        contextLine: contextLine,
        root: root,
        paintColor: paintColor,
        bandColor: bandColor,
        enabled: enabled,
      ),
    );
  }

  @override
  ConsumerState<HonorRequirementSheet> createState() =>
      _HonorRequirementSheetState();
}

class _HonorRequirementSheetState extends ConsumerState<HonorRequirementSheet> {
  late final TextEditingController _answer;
  late String _savedAnswer;
  bool _saving = false;
  bool _textExpanded = false;
  bool _referenceOpen = false;

  @override
  void initState() {
    super.initState();
    final row = _row(ref.read(userHonorProgressProvider(widget.honorId)).value);
    _savedAnswer = row?.textResponse ?? '';
    _answer = TextEditingController(text: _savedAnswer)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  UserHonorRequirementProgress? _row(
    List<UserHonorRequirementProgress>? progress,
  ) {
    for (final p in progress ?? const <UserHonorRequirementProgress>[]) {
      if (p.requirementId == widget.requirement.id) return p;
    }
    return null;
  }

  bool get _isDirty => _answer.text.trim() != _savedAnswer.trim();

  Future<void> _confirmDiscard() async {
    final confirm = await SacDialog.show(
      context,
      title: 'honors.requirements.unsaved_title'.tr(),
      content: 'honors.requirements.unsaved_content'.tr(),
      cancelLabel: 'honors.requirements.unsaved_stay'.tr(),
      confirmLabel: 'honors.requirements.unsaved_exit'.tr(),
      confirmIsDestructive: true,
    );
    if (confirm == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (!_isDirty) return;
    final answer = _answer.text.trim();
    final done = answer.isNotEmpty;
    final progress =
        ref.read(userHonorProgressProvider(widget.honorId)).value ?? const [];
    final row = _row(progress);

    // The progress as it will be once this answer is saved.
    final after = [
      for (final p in progress)
        if (p.requirementId == widget.requirement.id)
          p.copyWith(completed: done, textResponse: answer)
        else
          p,
      if (row == null)
        UserHonorRequirementProgress(
          requirementId: widget.requirement.id,
          requirementNumber: widget.requirement.requirementNumber,
          text: widget.requirement.text,
          completed: done,
          textResponse: answer,
        ),
    ];
    final root = widget.root;
    final updates = [
      {
        'requirementId': widget.requirement.id,
        'completed': done,
        'notes': row?.notes ?? '',
        'textResponse': answer,
      },
      if (root != null)
        ...evidenceParentUpdates(roots: [root], progress: after),
    ];

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier =
        ref.read(requirementProgressNotifierProvider(widget.honorId).notifier);
    final success = await notifier.bulkUpdate(updates);
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      // Everything saved: closing needs no confirmation.
      _savedAnswer = answer;
      navigator.pop();
      SacSnackBar.showMessenger(
        messenger,
        'honors.requirements.success_saved'.tr(),
        isSuccess: true,
        duration: const Duration(seconds: 2),
      );
    } else {
      final error =
          ref.read(requirementProgressNotifierProvider(widget.honorId)).error;
      SacSnackBar.showMessenger(
        messenger,
        userErrorMessage(error),
        isError: true,
      );
    }
  }

  /// A parent's evidence counts only on a completed row: after an upload
  /// creates the row, bring the parents in step.
  Future<void> _syncParents() async {
    final root = widget.root;
    if (root == null) return;
    final progress =
        await ref.read(userHonorProgressProvider(widget.honorId).future);
    final updates = evidenceParentUpdates(roots: [root], progress: progress);
    if (updates.isEmpty) return;
    await ref
        .read(requirementProgressNotifierProvider(widget.honorId).notifier)
        .bulkUpdate(updates);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final req = widget.requirement;
    final row =
        _row(ref.watch(userHonorProgressProvider(widget.honorId)).value);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final reference = req.referenceText?.trim() ?? '';
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.standard;
    final longText = req.text.length > 160;

    return PopScope(
      canPop: !_isDirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(title: widget.title, showClose: true),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('requirement-sheet-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.contextLine != null) ...[
                      Text(
                        widget.contextLine!,
                        style: TextStyle(
                          fontSize: SacFontSize.labelSmall,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    GestureDetector(
                      onTap: longText
                          ? () => setState(() => _textExpanded = !_textExpanded)
                          : null,
                      child: AnimatedSize(
                        duration: duration,
                        curve: SacMotion.easeOut,
                        alignment: Alignment.topLeft,
                        child: Text(
                          req.text,
                          key: const ValueKey('requirement-text'),
                          maxLines: !longText || _textExpanded ? null : 4,
                          overflow: !longText || _textExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: c.text,
                          ),
                        ),
                      ),
                    ),
                    if (longText)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _textExpanded = !_textExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _textExpanded
                                ? 'honors.requirements.see_less'.tr()
                                : 'honors.requirements.see_more'.tr(),
                            style: TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    HonorFieldCaption('honors.requirements.your_answer'.tr()),
                    SacTextField(
                      key: const ValueKey('requirement-answer'),
                      controller: _answer,
                      hint: 'honors.requirements.response_hint'.tr(),
                      maxLines: 5,
                      maxLength: 800,
                      enabled: widget.enabled,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    if (req.requiresEvidence) ...[
                      const SizedBox(height: 16),
                      HonorRequirementEvidence(
                        honorId: widget.honorId,
                        requirementId: req.id,
                        evidences: row?.evidences ?? const [],
                        paintColor: widget.paintColor,
                        enabled: widget.enabled,
                        onChanged: _syncParents,
                      ),
                    ],
                    if (reference.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      HonorReferenceCard(
                        text: reference,
                        open: _referenceOpen,
                        onToggle: () =>
                            setState(() => _referenceOpen = !_referenceOpen),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.enabled)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.borderLight)),
                ),
                child: SacButton.primary(
                  key: const ValueKey('requirement-save'),
                  text: 'honors.requirements.sheet_save'.tr(),
                  isLoading: _saving,
                  backgroundColor: widget.bandColor,
                  textColor: Colors.white,
                  // Nothing to save until the answer changes.
                  onPressed: _saving || !_isDirty ? null : _save,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Folded reference text: a tinted row that opens to show the reference.
class HonorReferenceCard extends StatelessWidget {
  const HonorReferenceCard({
    super.key,
    required this.text,
    required this.open,
    required this.onToggle,
  });

  final String text;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.standard;

    return Container(
      key: const ValueKey('requirement-reference'),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedBookOpen01,
                        size: 18,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'honors.requirements.reference_label'.tr(),
                          style: TextStyle(
                            fontSize: SacFontSize.titleSmall,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: duration,
                        curve: SacMotion.easeOut,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 18,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: duration,
              curve: SacMotion.easeOut,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          height: 1.5,
                          color: c.textSecondary,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}
