import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import 'gender_selector.dart';

/// Saves one value from an edit sheet.
///
/// Returns null on success (the sheet closes) or the error message to show
/// inline (the sheet stays open).
typedef ProfileSheetSave<T> = Future<String?> Function(T value);

/// Chrome shared by the edit sheets: title, one helper line, the editor, an
/// inline error and the primary "Save" button.
class ProfileSheetFrame extends StatelessWidget {
  const ProfileSheetFrame({
    super.key,
    required this.title,
    required this.helper,
    required this.child,
    required this.onSave,
    required this.isSaving,
    this.canSave = true,
    this.errorText,
  });

  final String title;
  final String helper;
  final Widget child;
  final VoidCallback onSave;
  final bool isSaving;
  final bool canSave;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(title: title, subtitle: helper),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: child,
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 10, 26, 0),
                  child: Text(
                    errorText!,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      fontWeight: FontWeight.w500,
                      color: c.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SacButton.primary(
                  text: 'common.save'.tr(),
                  isLoading: isSaving,
                  onPressed: (isSaving || !canSave) ? null : onSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Text field sheet ───────────────────────────────────────────────────────

/// Sheet with one autofocused [SacTextField] (a name or a surname).
///
/// When [requiredMessage] is set the field cannot be saved empty.
Future<bool?> showProfileTextSheet(
  BuildContext context, {
  required String title,
  required String helper,
  required String hint,
  required String initialValue,
  required ProfileSheetSave<String> onSave,
  String? requiredMessage,
}) {
  return showSacSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TextFieldSheet(
      title: title,
      helper: helper,
      hint: hint,
      initialValue: initialValue,
      requiredMessage: requiredMessage,
      onSave: onSave,
    ),
  );
}

class _TextFieldSheet extends StatefulWidget {
  const _TextFieldSheet({
    required this.title,
    required this.helper,
    required this.hint,
    required this.initialValue,
    required this.onSave,
    this.requiredMessage,
  });

  final String title;
  final String helper;
  final String hint;
  final String initialValue;
  final String? requiredMessage;
  final ProfileSheetSave<String> onSave;

  @override
  State<_TextFieldSheet> createState() => _TextFieldSheetState();
}

class _TextFieldSheetState extends State<_TextFieldSheet> {
  final _formKey = GlobalKey<FormState>();
  final _focus = FocusNode();
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final error = await widget.onSave(_controller.text.trim());
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetFrame(
      title: widget.title,
      helper: widget.helper,
      isSaving: _isSaving,
      errorText: _error,
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: SacTextField(
          controller: _controller,
          focusNode: _focus,
          hint: widget.hint,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          enabled: !_isSaving,
          onSubmitted: (_) => _submit(),
          validator: widget.requiredMessage == null
              ? null
              : (value) => (value == null || value.trim().isEmpty)
                  ? widget.requiredMessage
                  : null,
        ),
      ),
    );
  }
}

// ─── Gender sheet ───────────────────────────────────────────────────────────

/// Sheet with the [Gender] options as selectable rows plus "Save".
Future<bool?> showGenderSheet(
  BuildContext context, {
  required Gender? current,
  required ProfileSheetSave<Gender> onSave,
}) {
  return showSacSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GenderSheet(current: current, onSave: onSave),
  );
}

class _GenderSheet extends StatefulWidget {
  const _GenderSheet({required this.current, required this.onSave});

  final Gender? current;
  final ProfileSheetSave<Gender> onSave;

  @override
  State<_GenderSheet> createState() => _GenderSheetState();
}

class _GenderSheetState extends State<_GenderSheet> {
  Gender? _selected;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  Future<void> _submit() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final error = await widget.onSave(selected);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetFrame(
      title: 'profile.edit.gender_label'.tr(),
      helper: 'profile.edit.gender_select_subtitle'.tr(),
      isSaving: _isSaving,
      canSave: _selected != null && _selected != widget.current,
      errorText: _error,
      onSave: _submit,
      child: Column(
        children: [
          for (final gender in Gender.values)
            _GenderOptionRow(
              gender: gender,
              selected: _selected == gender,
              onTap: _isSaving
                  ? null
                  : () {
                      if (_selected != gender) HapticFeedback.selectionClick();
                      setState(() => _selected = gender);
                    },
            ),
        ],
      ),
    );
  }
}

class _GenderOptionRow extends StatelessWidget {
  const _GenderOptionRow({
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  final Gender gender;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final reduce = SacMotion.reduceMotionOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: SacPressable(
          onTap: onTap,
          enabled: onTap != null,
          pressedScale: SacMotion.rowPressScale,
          semanticLabel: gender.display(context),
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : SacMotion.standard,
            curve: SacMotion.easeOut,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? accent.light : c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: Border.all(
                color: selected ? accent.color : c.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  HugeIcon(
                    icon: gender.icon,
                    size: 22,
                    color: selected ? accent.color : c.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gender.display(context),
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? accent.color : c.text,
                      ),
                    ),
                  ),
                  if (selected)
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      size: 20,
                      color: accent.color,
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
