import 'package:flutter/material.dart';
import 'medico_tokens.dart';

/// Wrapper común para cada sección (Alergias, Enfermedades, etc.).
///
/// Header: icono coloreado + título + acción opcional ("Editar" / "Administrar").
class MedicoSectionCard extends StatelessWidget {
  /// Icono Material a mostrar dentro del badge coloreado.
  final IconData icon;

  /// Color de fondo del badge.
  final Color iconBg;

  /// Color del icono.
  final Color iconFg;

  /// Título de la sección.
  final String title;

  /// Texto de la acción a la derecha ("Editar", "Administrar", "+ Agregar"…).
  final String? actionLabel;

  final VoidCallback? onAction;

  /// Contenido de la sección (chips, lista de contactos, etc.).
  final Widget child;

  const MedicoSectionCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

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
    return Row(
      children: [
        Container(
          width: MedicoTokens.sectionIconBox,
          height: MedicoTokens.sectionIconBox,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(MedicoTokens.sectionIconRadius),
          ),
          child: Icon(icon, color: iconFg, size: 20),
        ),
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
