import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'medico_tokens.dart';

/// Wrapper común para cada sección (Alergias, Enfermedades, etc.).
///
/// Header: icono coloreado + título + acción opcional ("Editar" / "Administrar").
///
/// Supports two icon modes:
/// - [icon] + [iconBg] + [iconFg]: classic Material IconData badge.
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
  }) : assert(icon != null || iconWidget != null,
            'Provide either icon or iconWidget');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 18),
      decoration: BoxDecoration(
        color: MedicoTokens.paper,
        borderRadius: BorderRadius.circular(MedicoTokens.rCard),
        border: Border.all(color: MedicoTokens.ink150),
        boxShadow: MedicoTokens.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _header() {
    final badge = iconWidget != null
        ? Container(
            width: MedicoTokens.sectionIconBox,
            height: MedicoTokens.sectionIconBox,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius:
                  BorderRadius.circular(MedicoTokens.sectionIconRadius),
            ),
            alignment: Alignment.center,
            child: iconWidget,
          )
        : Container(
            width: MedicoTokens.sectionIconBox,
            height: MedicoTokens.sectionIconBox,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius:
                  BorderRadius.circular(MedicoTokens.sectionIconRadius),
            ),
            child: HugeIcon(icon: icon!, color: iconFg, size: 20),
          );

    return Row(
      children: [
        badge,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MedicoTokens.ink900,
              letterSpacing: -0.16,
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
