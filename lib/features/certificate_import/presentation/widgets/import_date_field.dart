import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_form_widgets.dart';

/// Extra line under the date: why the member should look at it.
enum ImportDateHint {
  none,

  /// Read with low confidence (under 0.8).
  review,

  /// The OCR read something that is not a usable date, so the field is empty.
  unreadable,

  /// Prefilled from what the OCR read and not changed yet.
  read,
}

/// Date field of the row editor with its validation message and hints.
class ImportDateField extends StatelessWidget {
  const ImportDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
    this.hint = ImportDateHint.none,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;
  final ImportDateHint hint;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    Widget? note;
    if (errorText != null) {
      note = Text(errorText!, style: theme.bodySmall?.copyWith(color: c.error));
    } else if (hint == ImportDateHint.review ||
        hint == ImportDateHint.unreadable) {
      note = Text(
        (hint == ImportDateHint.review
                ? 'certificate_import.editor.date_review'
                : 'certificate_import.editor.date_unreadable')
            .tr(),
        style: theme.bodySmall?.copyWith(
          color: AppColors.accentDark,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (hint == ImportDateHint.read) {
      note = Align(
        alignment: Alignment.centerLeft,
        child: SacBadge(
          label: 'certificate_import.editor.date_read'.tr(),
          variant: SacBadgeVariant.neutral,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActivityDatePickerField(
          label: label,
          value: value,
          enabled: true,
          onTap: onTap,
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Semantics(liveRegion: true, child: note),
          ),
      ],
    );
  }
}
