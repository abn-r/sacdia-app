import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';

/// Server limit of the evaluation notes.
const int _kNotesMaxLength = 500;

/// Points and notes an evaluator entered for a section.
class SupervisionEvaluation {
  const SupervisionEvaluation(this.points, this.notes);

  final int points;
  final String notes;
}

/// Opens the evaluation of [section]; null when the evaluator cancels.
Future<SupervisionEvaluation?> showSupervisionEvaluateSheet(
  BuildContext context,
  SupervisionFolderSection section,
) {
  return showSacSheet<SupervisionEvaluation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EvaluateSheet(section: section),
  );
}

/// The points are the decision, so they are the biggest thing on the sheet:
/// a large number with the maximum beside it and quick values (0, half, the
/// maximum) under it. Then an optional note for the club.
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

  int get _max => widget.section.maxPoints;

  @override
  void dispose() {
    _pointsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _validatePoints(String? value) {
    final points = int.tryParse((value ?? '').trim());
    if (points == null || points < 0 || points > _max) {
      return 'supervision.folders.points_invalid'.tr(args: ['$_max']);
    }
    return null;
  }

  void _confirm() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      SupervisionEvaluation(
        int.parse(_pointsCtrl.text.trim()),
        _notesCtrl.text.trim(),
      ),
    );
  }

  void _pick(int points) {
    setState(() => _pointsCtrl.text = '$points');
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    // 0, half and the maximum, without repeating a value.
    final quick = {0, (_max / 2).round(), _max}.toList()..sort();
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
                subtitle: 'supervision.folders.evaluate_subtitle'.tr(
                  args: [widget.section.name, supervisionCount(context, _max)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'supervision.folders.points_label'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      _PointsField(
                        controller: _pointsCtrl,
                        max: _max,
                        validator: _validatePoints,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var i = 0; i < quick.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _QuickValue(
                                value: quick[i],
                                onTap: () => _pick(quick[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      SacTextField(
                        controller: _notesCtrl,
                        label: 'supervision.folders.notes_label'.tr(),
                        hint: 'supervision.folders.evaluate_notes_hint'.tr(),
                        maxLines: 3,
                        maxLength: _kNotesMaxLength,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 20),
                      SacButton.primary(
                        text: 'supervision.folders.evaluate_save'.tr(),
                        icon: HugeIcons.strokeRoundedTick02,
                        labelMaxLines: 2,
                        onPressed: _confirm,
                      ),
                      const SizedBox(height: 8),
                      SacButton(
                        text: 'common.cancel'.tr(),
                        variant: SacButtonVariant.ghost,
                        fullWidth: true,
                        backgroundColor: c.surfaceVariant,
                        textColor: c.text,
                        labelMaxLines: 2,
                        onPressed: () => Navigator.pop(context),
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

/// Large number input with «de 400 pts» beside it; the border is the accent
/// while it holds focus and red when the value is not valid.
class _PointsField extends StatelessWidget {
  const _PointsField({
    required this.controller,
    required this.max,
    required this.validator,
  });

  final TextEditingController controller;
  final int max;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    return FormField<String>(
      validator: (_) => validator(controller.text),
      builder: (state) {
        final error = state.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Focus(
              child: Builder(
                builder: (context) {
                  final focused = Focus.of(context).hasFocus;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: error != null
                            ? c.error
                            : focused
                                ? accent
                                : c.border,
                        width: error != null || focused ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IntrinsicWidth(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 56),
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              textInputAction: TextInputAction.next,
                              onChanged: (_) =>
                                  state.didChange(controller.text),
                              cursorColor: accent,
                              style: TextStyle(
                                fontSize: SacFontSize.displayMedium,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'supervision.folders.points_of_max'
                                .tr(args: [supervisionCount(context, max)]),
                            style: TextStyle(
                              fontSize: SacFontSize.titleMedium,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.error,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A typical value: tapping it fills the field.
class _QuickValue extends StatelessWidget {
  const _QuickValue({required this.value, required this.onTap});

  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacPressable(
      onTap: onTap,
      semanticLabel: 'supervision.folders.quick_value'
          .tr(args: [supervisionCount(context, value)]),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Text(
          supervisionCount(context, value),
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            fontWeight: FontWeight.w600,
            color: c.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
