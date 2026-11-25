import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

/// Bottom sheet that collects the text of a supervision decision: the reason
/// of a rejection or the optional comment of a review.
///
/// Keyboard-safe. Returns the trimmed text when the user confirms (empty when
/// [minLength] is 0 and nothing was written) and `null` when they cancel or
/// dismiss. A text shorter than [minLength] shows an inline error and keeps
/// the sheet open, so the server never has to reject the length.
Future<String?> showSupervisionDecisionSheet({
  required BuildContext context,
  required String title,
  required String fieldLabel,
  required String confirmLabel,
  String? message,
  String? fieldHint,
  int minLength = 0,
  int maxLength = 500,
  bool destructive = true,
  String? initialText,
}) {
  return showSacSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DecisionSheet(
      title: title,
      message: message,
      fieldLabel: fieldLabel,
      fieldHint: fieldHint,
      confirmLabel: confirmLabel,
      minLength: minLength,
      maxLength: maxLength,
      destructive: destructive,
      initialText: initialText,
    ),
  );
}

class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({
    required this.title,
    required this.message,
    required this.fieldLabel,
    required this.fieldHint,
    required this.confirmLabel,
    required this.minLength,
    required this.maxLength,
    required this.destructive,
    required this.initialText,
  });

  final String? initialText;
  final String title;
  final String? message;
  final String fieldLabel;
  final String? fieldHint;
  final String confirmLabel;
  final int minLength;
  final int maxLength;
  final bool destructive;

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  late final _textCtrl = TextEditingController(text: widget.initialText ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(context, _textCtrl.text.trim());
  }

  String? _validate(String? value) {
    final length = (value ?? '').trim().length;
    if (length >= widget.minLength) return null;
    return length == 0
        ? 'supervision.decision.text_required'.tr()
        : 'supervision.decision.text_too_short'
            .tr(args: ['${widget.minLength}']);
  }

  @override
  Widget build(BuildContext context) {
    final confirm = widget.destructive
        ? SacButton.destructive(
            text: widget.confirmLabel,
            icon: HugeIcons.strokeRoundedCancel01,
            labelMaxLines: 2,
            onPressed: _confirm,
          )
        : SacButton.success(
            text: widget.confirmLabel,
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            labelMaxLines: 2,
            onPressed: _confirm,
          );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(title: widget.title, subtitle: widget.message),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                      key: _formKey,
                      child: SacTextField(
                        controller: _textCtrl,
                        label: widget.fieldLabel,
                        hint: widget.fieldHint,
                        maxLines: 4,
                        maxLength: widget.maxLength,
                        textCapitalization: TextCapitalization.sentences,
                        validator: _validate,
                      ),
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
                        Expanded(child: confirm),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
