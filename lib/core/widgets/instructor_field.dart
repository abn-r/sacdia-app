import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import 'instructor_avatar.dart';
import 'instructor_picker.dart';
import 'instructor_selection.dart';
import 'sac_button.dart';
import 'sac_picker_field.dart';

/// Optional "Instructor o instructora" field: shows who was picked (a person
/// of the Local Field with photo, or a typed name flagged as unverified),
/// opens [InstructorPicker] on tap and lets the member remove the choice.
///
/// It owns no state: the parent keeps the [selection] and decides what to do
/// with [onChanged] (save now, or keep it until the form is saved).
class InstructorField extends StatelessWidget {
  const InstructorField({
    super.key,
    required this.selection,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.showHelp = true,
    this.readOnly = false,
    this.isLoading = false,
  });

  final InstructorSelection selection;
  final ValueChanged<InstructorSelection> onChanged;
  final String? errorText;
  final bool enabled;

  /// "Tu Campo Local revisa este dato. No avisamos a la persona." (D8).
  final bool showHelp;

  /// Shows who was declared without letting the member change it. Empty says
  /// "Sin instructor registrado". Hides the help text and "Quitar".
  final bool readOnly;

  /// A save is in flight: the field cannot be tapped.
  final bool isLoading;

  Future<void> _pick(BuildContext context) async {
    final picked = await InstructorPicker.show(context);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final label = 'instructor.title'.tr();
    final name = selection.isNone ? null : selection.displayName;
    final subtitle = switch (selection.kind) {
      InstructorKind.user => 'instructor.local_field_person'.tr(),
      InstructorKind.external => 'instructor.unverified'.tr(),
      InstructorKind.none => null,
    };
    final spoken = switch (selection.kind) {
      InstructorKind.user => 'instructor.semantics_user'.tr(
          namedArgs: {'name': selection.displayName},
        ),
      InstructorKind.external => 'instructor.semantics_external'.tr(
          namedArgs: {'name': selection.displayName},
        ),
      InstructorKind.none => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacPickerField(
          label: label,
          hint:
              (readOnly ? 'instructor.none_registered' : 'instructor.add_hint')
                  .tr(),
          icon: selection.isExternal
              ? HugeIcons.strokeRoundedUserEdit01
              : HugeIcons.strokeRoundedUserAdd01,
          selectedName: name,
          selectedSubtitle: subtitle,
          leading: selection.isUser
              ? InstructorAvatar(
                  name: selection.displayName,
                  photoUrl: selection.photoUrl,
                  size: 28,
                )
              : null,
          errorText: errorText,
          semanticsLabel: spoken,
          enabled: enabled && !readOnly,
          isLoading: isLoading,
          onTap: () => _pick(context),
        ),
        if (!selection.isNone && enabled && !readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: SacButton.ghost(
              text: 'instructor.remove'.tr(),
              icon: HugeIcons.strokeRoundedCancel01,
              onPressed: () => onChanged(const InstructorSelection.none()),
            ),
          ),
        if (showHelp && !readOnly)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'instructor.help'.tr(),
              style: theme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
      ],
    );
  }
}
