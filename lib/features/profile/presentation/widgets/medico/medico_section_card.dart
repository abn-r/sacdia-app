import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'medico_tokens.dart';

/// Wrapper común para cada sección (Alergias, Enfermedades, etc.).
///
/// Header: icono coloreado + título + acción opcional ("Editar" / "Administrar").
///
/// Supports two icon modes:
/// - [icon] + [iconBg] + [iconFg]: HugeIcons badge.
/// - [iconWidget]: arbitrary widget placed inside the badge box (e.g. HugeIcon).
///   When [iconWidget] is provided, [icon], [iconBg] and [iconFg] are ignored.
class MedicoSectionCard extends StatelessWidget {
  /// Icono HugeIcons a mostrar dentro del badge coloreado.
  final List<List<dynamic>>? icon;

  /// Color de fondo del badge.
  final Color iconBg;

  /// Color del icono.
  final Color iconFg;

  /// Widget alternativo para el área de icono (reemplaza icon+iconBg+iconFg).
  final Widget? iconWidget;

  /// Título de la sección.
  final String title;

  /// Texto de la acción a la derecha ("Editar", "Administrar", "+ Agregar"…).
  final String? actionLabel;

  final VoidCallback? onAction;

  /// Contenido de la sección (chips, lista de contactos, etc.).
  final Widget child;

  /// Variante compacta para secciones secundarias que no deben robar altura.
  final bool dense;

  const MedicoSectionCard({
    super.key,
    this.icon,
    this.iconBg = MedicoTokens.coral100,
    this.iconFg = MedicoTokens.coral600,
    this.iconWidget,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.dense = false,
  }) : assert(icon != null || iconWidget != null,
            'Provide either icon or iconWidget');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: dense
          ? const EdgeInsets.fromLTRB(12, 10, 10, 12)
          : const EdgeInsets.fromLTRB(16, 16, 12, 18),
      decoration: BoxDecoration(
        color: MedicoTokens.paper,
        borderRadius: BorderRadius.circular(
          dense ? 16 : MedicoTokens.rCard,
        ),
        border: Border.all(color: MedicoTokens.ink150),
        boxShadow: dense ? const [] : MedicoTokens.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          SizedBox(height: dense ? 8 : 14),
          child,
        ],
      ),
    );
  }

  Widget _header() {
    final badge = iconWidget != null
        ? Container(
            width: dense ? 30 : MedicoTokens.sectionIconBox,
            height: dense ? 30 : MedicoTokens.sectionIconBox,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(
                  dense ? 10 : MedicoTokens.sectionIconRadius),
            ),
            alignment: Alignment.center,
            child: iconWidget,
          )
        : Container(
            width: dense ? 30 : MedicoTokens.sectionIconBox,
            height: dense ? 30 : MedicoTokens.sectionIconBox,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(
                  dense ? 10 : MedicoTokens.sectionIconRadius),
            ),
            child: HugeIcon(icon: icon!, color: iconFg, size: dense ? 18 : 20),
          );

    return Row(
      children: [
        badge,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: dense ? 14 : 16,
              fontWeight: FontWeight.w700,
              color: MedicoTokens.ink900,
              letterSpacing: dense ? -0.08 : -0.16,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: MedicoTokens.coral500,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
