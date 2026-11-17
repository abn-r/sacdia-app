import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../utils/section_board.dart';

/// Colores del acento del usuario para fondos suaves (avatar de persona):
/// pastel en claro, tinte sobre la superficie en oscuro.
({Color background, Color foreground}) investitureAccentTint(
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

/// Avatar circular con las iniciales de la persona. [muted] lo apaga (quien
/// aún no cumple).
class InvestitureAvatar extends StatelessWidget {
  const InvestitureAvatar({
    super.key,
    required this.name,
    this.muted = false,
    this.size = 36,
  });

  final String name;
  final bool muted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tint = investitureAccentTint(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: muted ? c.surfaceVariant : tint.background,
          shape: BoxShape.circle,
        ),
        child: Text(
          investitureInitials(name),
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            fontWeight: FontWeight.w600,
            color: muted ? c.textSecondary : tint.foreground,
          ),
        ),
      ),
    );
  }
}

/// Círculo con un ícono (fila de clase, de solicitud o de resultado).
class InvestitureIconBadge extends StatelessWidget {
  const InvestitureIconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 32,
  });

  final HugeIconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: buildIcon(icon, size: size * 0.53, color: foreground),
      ),
    );
  }
}

/// Casilla del tablero: 24 dibujados, la fila entera es el objetivo táctil.
class InvestitureSelectBox extends StatelessWidget {
  const InvestitureSelectBox({super.key, required this.selected});

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

/// Fila de una persona dentro de un `SacGroupedSection`: [leading], título,
/// una línea de detalle, [extra] bajo el detalle y [trailing] al final.
class InvestitureRow extends StatelessWidget {
  const InvestitureRow({
    super.key,
    required this.leading,
    required this.title,
    this.detail,
    this.detailColor,
    this.extra,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.selected,
    this.detailMaxLines = 1,
  });

  final Widget leading;
  final String title;
  final String? detail;
  final Color? detailColor;
  final Widget? extra;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Si no es nulo, la fila se anuncia como casilla.
  final bool? selected;
  final int detailMaxLines;

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
                        color: c.text,
                      ),
                    ),
                    if (detail != null && detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: detailMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          height: 1.35,
                          color: detailColor ?? c.textSecondary,
                        ),
                      ),
                    ],
                    if (extra != null) ...[const SizedBox(height: 6), extra!],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                // El título manda: el final nunca ocupa más de la mitad.
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

    final tappable =
        onTap == null ? body : SacInkWell(onTap: onTap, child: body);
    return Semantics(
      container: true,
      label: semanticLabel,
      checked: selected,
      button: onTap != null && selected == null,
      child: tappable,
    );
  }
}

/// Chevron de fila navegable.
class InvestitureChevron extends StatelessWidget {
  const InvestitureChevron({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 18,
          color: context.sac.textTertiary,
        ),
      );
}

/// Enlace de texto del encabezado de un grupo ("Elegir todos"), con objetivo
/// táctil de 44.
class InvestitureEyebrowAction extends StatelessWidget {
  const InvestitureEyebrowAction({
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
                      : investitureAccentTint(context).foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pie fijo y difuminado con la acción principal y una nota.
class InvestitureFooter extends StatelessWidget {
  const InvestitureFooter({super.key, required this.button, this.note});

  final Widget button;
  final String? note;

  /// Alto aproximado, para dejar margen al final de la lista.
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

/// Tarjeta con borde que agrupa filas (como `SacGroupedSection` pero sin
/// encabezado). Las filas se separan con divisores.
class InvestitureCard extends StatelessWidget {
  const InvestitureCard({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(20, 16, 20, 0),
  });

  final List<Widget> children;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: margin,
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: BorderSide(color: c.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, indent: 58, color: c.divider),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
