import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/certificate_import_class_option.dart';

/// Short radio list of the classes of one club type. No search: there are
/// few. Shows three still skeleton rows while loading and a retry on error.
class ClassPickerList extends StatelessWidget {
  const ClassPickerList({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    this.errorText,
    this.suggestedId,
  });

  /// Null while loading.
  final List<CertificateImportClassOption>? options;
  final int? selectedId;
  final ValueChanged<CertificateImportClassOption> onSelect;
  final String? errorText;

  /// Class proposed by the OCR and not yet confirmed ("Sugerida").
  final int? suggestedId;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final list = options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'certificate_import.editor.class_field'.tr(),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (list == null)
          for (var i = 0; i < 3; i++) const _SkeletonRow()
        else
          for (final option in list)
            _ClassRow(
              option: option,
              selected: option.id == selectedId,
              suggested: option.id == suggestedId,
              onTap: () => onSelect(option),
            ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(errorText!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.error)),
            ),
          ),
      ],
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({
    required this.option,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  final CertificateImportClassOption option;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: option.name,
      excludeSemantics: true,
      child: SacPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: SacMotion.switcher,
          curve: SacMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.08) : c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(
              color: selected ? accent : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? accent : c.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.text),
                ),
              ),
              if (suggested)
                Text(
                  'certificate_import.editor.suggested'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: c.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
    );
  }
}

/// Inline retry for a failed catalog load, in the same slot as the list.
class ClassPickerError extends StatelessWidget {
  const ClassPickerError(
      {super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.sac.textSecondary)),
        SacButton.ghost(
          text: 'certificate_import.errors.retry'.tr(),
          onPressed: onRetry,
        ),
      ],
    );
  }
}
