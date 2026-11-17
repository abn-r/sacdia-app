import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_member_avatar.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/insurance_overview.dart';
import '../utils/insurance_formatting.dart';

/// Small building blocks shared by the insurance screens, drawn like the
/// other redesigned lists (investitures, units).

/// Colors of the accent for soft backgrounds.
({Color background, Color foreground}) insuranceAccentTint(
  BuildContext context,
) {
  final accent = SacAccent.of(context);
  if (Theme.brightnessOf(context) == Brightness.dark) {
    return (
      background: Color.alphaBlend(
        accent.color.withValues(alpha: 0.2),
        context.sac.surface,
      ),
      foreground: accent.forHighContrast(Brightness.dark).color,
    );
  }
  return (background: accent.light, foreground: accent.dark);
}

/// Avatar of a person: photo or initials, dimmed when [muted].
class InsuranceAvatar extends StatelessWidget {
  const InsuranceAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.muted = false,
  });

  final String name;
  final String? imageUrl;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: muted ? 0.55 : 1,
        child: SacMemberAvatar(name: name, imageUrl: imageUrl, size: 36),
      ),
    );
  }
}

/// Status of a person as a chip: "Asegurado", "Sin seguro", "En revisión"...
class InsuranceStatusChip extends StatelessWidget {
  const InsuranceStatusChip({super.key, required this.status});

  final InsurancePersonStatus status;

  @override
  Widget build(BuildContext context) {
    final label = insuranceStatusLabel(status);
    return switch (status) {
      InsurancePersonStatus.covered => SacBadge.success(label: label),
      InsurancePersonStatus.inOrder ||
      InsurancePersonStatus.inReview =>
        SacBadge.info(label: label),
      InsurancePersonStatus.proofRejected => SacBadge.error(label: label),
      InsurancePersonStatus.uninsured =>
        SacBadge(label: label, variant: SacBadgeVariant.neutral),
    };
  }
}

/// Checkbox of the issue list: 24 drawn, the whole row is the tap target.
class InsuranceSelectBox extends StatelessWidget {
  const InsuranceSelectBox({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          border: Border.all(
            color: selected ? accent.color : c.textTertiary,
            width: 2,
          ),
        ),
        child: selected
            ? buildIcon(
                HugeIcons.strokeRoundedTick02,
                size: 15,
                color: accent.onColor,
              )
            : null,
      ),
    );
  }
}

/// Radio of the reassign list.
class InsuranceRadio extends StatelessWidget {
  const InsuranceRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? accent : c.textTertiary,
            width: 2,
          ),
        ),
        child: selected
            ? Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              )
            : null,
      ),
    );
  }
}

/// Chevron of a row that opens something.
class InsuranceChevron extends StatelessWidget {
  const InsuranceChevron({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 18,
          color: context.sac.textTertiary,
        ),
      );
}

/// One row of a grouped list: [leading], title, one detail line and [trailing].
class InsuranceRow extends StatelessWidget {
  const InsuranceRow({
    super.key,
    required this.leading,
    required this.title,
    this.detail,
    this.detailIsError = false,
    this.titleMuted = false,
    this.trailing,
    this.onTap,
    this.selected,
    this.semanticLabel,
  });

  final Widget leading;
  final String title;
  final String? detail;
  final bool detailIsError;
  final bool titleMuted;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Not null: the row is announced as a checkbox (or radio when
  /// [asRadio]).
  final bool? selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final detail = this.detail;
    final trailing = this.trailing;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: titleMuted ? c.textSecondary : c.text,
                      ),
                    ),
                    if (detail != null && detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          height: 1.35,
                          color: detailIsError
                              ? c.onErrorContainer
                              : c.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                // The name wins: the end never takes more than half the row.
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: constraints.maxWidth * 0.5),
                  child: trailing,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      checked: selected,
      button: onTap != null && selected == null,
      child: onTap == null ? body : SacInkWell(onTap: onTap, child: body),
    );
  }
}

/// Round icon of a "To attend" row, tinted by the kind of thing to do.
class InsuranceIconBadge extends StatelessWidget {
  const InsuranceIconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final HugeIconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: buildIcon(icon, size: 17, color: foreground),
      ),
    );
  }
}

/// Text link at the end of a group header ("Elegir todos"), 44 tall.
class InsuranceEyebrowAction extends StatelessWidget {
  const InsuranceEyebrowAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: SacInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w600,
                  color: onTap == null
                      ? context.sac.textTertiary
                      : insuranceAccentTint(context).foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed, blurred footer with the main action and a note.
class InsuranceFooter extends StatelessWidget {
  const InsuranceFooter({super.key, required this.button, this.note});

  final Widget button;
  final String? note;

  /// Room to leave at the end of the list.
  static const double height = 120;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final note = this.note;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: c.canvas.withValues(alpha: 0.88),
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  button,
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      note,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.4,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label and value in a grouped card (Importe, Seguro): [onTap] adds a
/// chevron.
class InsuranceKvRow extends StatelessWidget {
  const InsuranceKvRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool emphasis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        // Label takes the free space; the value keeps its natural width
        // (capped at 60%) so it always hugs the trailing edge.
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: emphasis
                        ? SacFontSize.titleMedium
                        : SacFontSize.titleSmall,
                    fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
                    color: emphasis ? c.text : c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: SacFontSize.titleMedium,
                    fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                    color: emphasis ? c.text : c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const InsuranceChevron(),
              ],
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      label: '$label, $value',
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null ? body : SacInkWell(onTap: onTap, child: body),
    );
  }
}

/// Label and value on one line inside a soft box (the cost, the year). Both
/// sides can wrap, so a long label or large text never overflows.
class InsuranceBoxLine extends StatelessWidget {
  const InsuranceBoxLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      container: true,
      label: '$label, $value',
      excludeSemantics: true,
      // Label at its natural width (capped at 45%), value takes the rest and
      // hugs the trailing edge. A flex split would leave a gap after short
      // labels ("Seguro") and wrap long values early.
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: SacFontSize.titleSmall,
                  color: c.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: SacFontSize.titleSmall,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
