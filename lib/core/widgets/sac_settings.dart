import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Settings section: optional uppercase [title] above a rounded bordered card.
///
/// Children are stacked as-is; separate rows with [SacSettingsDivider].
///
/// ```dart
/// SacSettingsGroup(title: 'Cuenta', children: [
///   SacSettingsTile(icon: HugeIcons.strokeRoundedQrCode, title: 'QR', onTap: open),
///   const SacSettingsDivider(),
///   SacSettingsSwitchTile(icon: icon, title: 'Push', value: on, onChanged: set),
/// ])
/// ```
class SacSettingsGroup extends StatelessWidget {
  const SacSettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final card = Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(children: children),
    );
    if (title == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              title!,
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                color: c.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        card,
      ],
    );
  }
}

/// Hairline divider between rows of a [SacSettingsGroup] (indented past icon).
class SacSettingsDivider extends StatelessWidget {
  const SacSettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 60,
        color: context.sac.borderLight,
      );
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final HugeIconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        ),
        child: Center(child: HugeIcon(icon: icon, color: color, size: 18)),
      ),
    );
  }
}

/// Tappable settings row: icon badge, title, optional subtitle, trailing or
/// chevron (when [onTap] is set). Icon uses the accent color; [destructive]
/// switches icon and title to the error color (logout, delete). Min 48dp.
///
/// ```dart
/// SacSettingsTile(icon: HugeIcons.strokeRoundedLogout02, title: 'Salir',
///     destructive: true, onTap: logout)
/// ```
class SacSettingsTile extends StatelessWidget {
  const SacSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final HugeIconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final iconColor = destructive ? c.error : SacAccent.of(context).color;
    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _IconBadge(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w500,
                        color: destructive ? c.error : c.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                ExcludeSemantics(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: c.textTertiary,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings row with a [Switch]. [onChanged] null disables the switch.
/// [indent] nests it under a master toggle; [muted] greys the icon (use when
/// the master toggle is off). Announced as a toggle with its on/off state.
///
/// ```dart
/// SacSettingsSwitchTile(icon: icon, title: 'Avisos', value: on, onChanged: set)
/// ```
class SacSettingsSwitchTile extends StatelessWidget {
  const SacSettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.indent = false,
    this.muted = false,
  });

  final HugeIconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool indent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final iconColor =
        muted ? c.textTertiary : (indent ? c.textSecondary : accent);
    return Semantics(
      container: true,
      label: title,
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.only(
              left: indent ? 28 : 14,
              right: 14,
              top: 11,
              bottom: 11,
            ),
            child: Row(
              children: [
                _IconBadge(icon: icon, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w500,
                          color: c.text,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SacPressable(
                  listenOnly: true,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: accent,
                    activeTrackColor: accent.withValues(alpha: 0.4),
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

/// Read-only fact row: icon and label on the left, the value on the right
/// (optional second line under it). [emphasis] makes the value larger, for
/// totals. With [onTap] it shows a chevron and opens something.
///
/// ```dart
/// SacSettingsValueTile(icon: HugeIcons.strokeRoundedCalendar03,
///     label: 'Vence', value: '21 nov 2026')
/// ```
class SacSettingsValueTile extends StatelessWidget {
  const SacSettingsValueTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.emphasis = false,
    this.valueColor,
    this.onTap,
  });

  final HugeIconData icon;
  final String label;
  final String value;
  final String? sub;
  final bool emphasis;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            HugeIcon(icon: icon, size: 18, color: c.textSecondary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: emphasis
                          ? SacFontSize.titleLarge
                          : SacFontSize.bodyMedium,
                      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
                      color: valueColor ?? c.text,
                      height: 1.3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textTertiary,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 16,
                  color: c.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return MergeSemantics(child: SacInkWell(onTap: onTap, child: row));
  }
}

/// Small note under a [SacSettingsGroup], like an iOS section footer.
class SacSettingsFooter extends StatelessWidget {
  const SacSettingsFooter(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: SacFontSize.bodySmall,
          color: context.sac.textTertiary,
          height: 1.35,
        ),
      ),
    );
  }
}

/// The screen's main action pinned at the bottom, above the tab bar.
class SacPinnedActionBar extends StatelessWidget {
  const SacPinnedActionBar({super.key, required this.child});

  /// Usually a [SacButton.primary]; a Row of two buttons also works.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: child,
        ),
      ),
    );
  }
}
