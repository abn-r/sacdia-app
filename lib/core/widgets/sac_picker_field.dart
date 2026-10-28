import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

/// Tappable form field that opens a picker (sheet, list, dialog).
///
/// States: empty (shows [hint]), filled ([selectedName], optional
/// [selectedSubtitle], [leading] and a [badge] stamp), loading and error
/// ([errorText] under the field, with a red border). The content crossfades
/// when it goes from empty to filled (Reduced Motion keeps the fade).
class SacPickerField extends StatelessWidget {
  final String label;
  final String hint;
  final HugeIconData icon;
  final String? selectedName;
  final String? selectedSubtitle;

  /// Replaces the field icon once a value is chosen (for example an image).
  final Widget? leading;

  /// Short stamp next to the value, such as "Sugerida".
  final String? badge;
  final String? errorText;

  /// Replaces the spoken "label: value" when the field says more than that.
  final String? semanticsLabel;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isLoading;

  const SacPickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.selectedName,
    this.selectedSubtitle,
    this.leading,
    this.badge,
    this.errorText,
    this.semanticsLabel,
    this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hasValue = selectedName != null;
    final hasError = errorText != null;
    final accent = SacAccent.of(context).color;
    final borderColor = hasError
        ? c.error
        : hasValue
            ? accent.withValues(alpha: 0.4)
            : c.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          enabled: enabled && !isLoading,
          label: semanticsLabel ??
              (hasValue ? '$label: $selectedName' : '$label: $hint'),
          excludeSemantics: true,
          // excludeSemantics drops the gesture's own tap action: keep it.
          onTap: (enabled && !isLoading) ? onTap : null,
          child: GestureDetector(
            onTap: (enabled && !isLoading) ? onTap : null,
            child: AnimatedContainer(
              duration: SacMotion.switcher,
              curve: SacMotion.easeOut,
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: enabled ? c.surface : c.surfaceVariant,
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    offset: const Offset(0, 3),
                    blurRadius: 20,
                  ),
                ],
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(
                  color: borderColor,
                  width: hasValue || hasError ? 1.5 : 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  if (hasValue && leading != null)
                    leading!
                  else
                    HugeIcon(
                      icon: icon,
                      size: 20,
                      color: hasValue ? accent : c.textSecondary,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isLoading
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 20,
                              child: FittedBox(child: SacLoadingSmall()),
                            ),
                          )
                        : SacStateSwap(
                            child: _content(context, theme, hasValue),
                          ),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    size: 22,
                    color: enabled ? c.textSecondary : c.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                errorText!,
                style: theme.textTheme.bodySmall?.copyWith(color: c.error),
              ),
            ),
          ),
      ],
    );
  }

  Widget _content(BuildContext context, ThemeData theme, bool hasValue) {
    final c = context.sac;
    if (!hasValue) {
      return Align(
        key: const ValueKey('picker-empty'),
        alignment: Alignment.centerLeft,
        child: Text(
          hint,
          style: theme.textTheme.bodyMedium?.copyWith(color: c.textTertiary),
        ),
      );
    }
    return Align(
      key: ValueKey('picker-$selectedName'),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedName!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: c.text),
          ),
          if (selectedSubtitle != null)
            Text(
              selectedSubtitle!,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
