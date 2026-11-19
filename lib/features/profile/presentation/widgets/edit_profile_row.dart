import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Minimum height of an edit row: above the 44dp touch target.
const double kEditProfileRowMinHeight = 52;

/// Settings-style row of the edit profile screen: label on the left, current
/// value on the right (secondary text) and a chevron. The whole row is the tap
/// target. An empty value shows [emptyLabel] in the accent color.
class EditProfileRow extends StatelessWidget {
  const EditProfileRow({
    super.key,
    required this.label,
    required this.value,
    required this.emptyLabel,
    required this.onTap,
  });

  final String label;

  /// Already formatted; null or blank shows [emptyLabel].
  final String? value;

  /// Already translated ("Add"), shown in the accent color when [value] is
  /// empty.
  final String emptyLabel;
  final VoidCallback? onTap;

  bool get _isEmpty => value == null || value!.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final reduce = SacMotion.reduceMotionOf(context);
    final shown = _isEmpty ? emptyLabel : value!;

    return SacPressable(
      onTap: onTap,
      enabled: onTap != null,
      pressedScale: SacMotion.rowPressScale,
      semanticLabel: '$label, $shown',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kEditProfileRowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: reduce ? Duration.zero : SacMotion.switcher,
                    switchInCurve: SacMotion.easeOut,
                    child: Align(
                      key: ValueKey(shown),
                      alignment: Alignment.centerRight,
                      child: Text(
                        shown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight:
                              _isEmpty ? FontWeight.w600 : FontWeight.w400,
                          color: _isEmpty ? accent : c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: c.textTertiary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row with a switch ("Baptized"). The whole row toggles; the switch is only
/// the indicator.
class EditProfileSwitchRow extends StatelessWidget {
  const EditProfileSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final enabled = onChanged != null;

    return Semantics(
      container: true,
      label: label,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
      excludeSemantics: true,
      child: SacPressable(
        onTap: enabled ? () => onChanged!(!value) : null,
        enabled: enabled,
        pressedScale: SacMotion.rowPressScale,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: kEditProfileRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Switch(
                    value: value,
                    onChanged: enabled ? (_) {} : null,
                    // Same look as SacSettingsSwitchTile: the accent only
                    // when on; off keeps the theme's neutral thumb.
                    activeThumbColor: accent.color,
                    activeTrackColor: accent.color.withValues(alpha: 0.4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
