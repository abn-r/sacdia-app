import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/certificate_import_class_option.dart';
import 'import_catalog_images.dart';

/// Short list of the classes of one club type, each with its logo and a check
/// on the chosen one. No search: there are few. Shows three still skeleton
/// rows while loading and a retry on error.
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
        Material(
          color: c.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            side: BorderSide(
              color: errorText == null ? c.border : c.error,
            ),
          ),
          child: Column(
            children: [
              if (list == null)
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 66, color: c.divider),
                  const _SkeletonRow(),
                ]
              else
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 66, color: c.divider),
                  _ClassRow(
                    option: list[i],
                    selected: list[i].id == selectedId,
                    suggested: list[i].id == suggestedId,
                    onTap: () => onSelect(list[i]),
                  ),
                ],
            ],
          ),
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
      child: SacInkWell(
        onTap: onTap,
        pressedScale: SacMotion.rowPressScale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                ImportClassLogo(
                  assetCode: option.assetCode,
                  name: option.name,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.name,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
                if (suggested) ...[
                  SacBadge(label: 'certificate_import.editor.suggested'.tr()),
                  const SizedBox(width: 8),
                ],
                if (selected)
                  HugeIcon(
                    key: const ValueKey('class-selected-check'),
                    icon: HugeIcons.strokeRoundedTick02,
                    size: 22,
                    color: accent,
                  ),
              ],
            ),
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
      height: 56,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
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
