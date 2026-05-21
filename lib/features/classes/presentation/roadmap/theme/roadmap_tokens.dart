import 'package:flutter/material.dart';

/// Tokens de diseño extraídos del prototipo HTML.
class RoadmapTokens {
  // Tipografía base — sustituye fontFamily si usas una fuente custom global.
  static const String fontFamily = 'sans-serif';

  // Colores de marca SACDIA por track
  static const Color avAccent = Color(0xFF4FB37C);
  static const Color cqAccent = Color(0xFF3D6FA5);
  static const Color gmAccent = Color(0xFFC99036);

  // Estados
  static const Color statusDone = Color(0xFF4FB37C);
  static const Color statusCurrent = Color(0xFFE57460);
  static const Color statusExpired = Color(0xFFBE123C);
  static const Color statusLocked = Color(0xFFB0B5BF);

  // Texto (hardcoded — el roadmap tiene fondo propio con gradiente de cielo
  // que garantiza contraste suficiente en ambos modos)
  static const Color textPrimary = Color(0xFF20232A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9AA0AB);
  static const Color textLockedBg = Color(0xFFC7CBD2);

  // Fondos por banda (gradiente de cielo según hora del día simbólica)
  // Aventureros: mañana clara
  static const Color bgAvTop = Color(0xFFD8ECFB);
  static const Color bgAvBottom = Color(0xFFF8F1DA);
  // Conquistadores: tarde
  static const Color bgCqTop = Color(0xFFF8E3C8);
  static const Color bgCqBottom = Color(0xFFC8DEC4);
  // Guías Mayores: anochecer
  static const Color bgGmTop = Color(0xFF6E5A9B);
  static const Color bgGmBottom = Color(0xFF1A1838);

  // Card translúcido para etiquetas de clase
  static Color labelCardBg = Colors.white.withValues(alpha: 0.95);

  // Espaciados
  static const double nodePadInside = 24; // padding lado del path
  static const double nodePadOutside = 80; // padding lado libre
  static const double nodeShieldSize = 128; // tamaño de la imagen
  static const double nodeRowGap = 22; // gap vertical entre nodos
  static const double frameWidth = 402; // ancho de referencia (iPhone)

  // Path serpenteante
  //
  // Derivación geométrica del slot del conector
  // ─────────────────────────────────────────────
  // Distancia vertical entre shield-bottom del nodo anterior y
  // shield-top del nodo actual (en coordenadas del Stack del nodo actual,
  // donde y=0 es el top del escudo current):
  //
  //   gapBetweenShields = SizedBox(h:12) + label(≈38) + nodeRowGap(22) = 72
  //
  // Queremos que la curva se solape 8 px DENTRO de cada escudo:
  //   shieldOverlap = 8
  //
  // Por tanto:
  //   pathHeight = gapBetweenShields + 2 * shieldOverlap = 72 + 16 = 88
  //
  // El Positioned.top en el Stack del nodo actual debe colocar el borde
  // superior del slot exactamente en (shield-bottom prev) + shieldOverlap:
  //   top = -(gapBetweenShields + shieldOverlap) = -(72 + 8) = -80
  //
  // connectorVerticalInset se mantiene en 4 px como ajuste fino;
  // el slot ya cubre el overlap, el inset sólo suaviza los endpoints.
  static const double pathHeight = 88;
  static const double pathStrokeWidth = 6;
  static const double pathOpacity = 0.6;

  // Offset del Positioned del conector dentro del Stack del nodo actual.
  // Derivado: -(gapBetweenShields=72 + shieldOverlap=8) = -80.
  static const double connectorSlotTopOffset = -80;

  // Inset fino para que los endpoints de la curva no queden en el pixel
  // exacto del borde del slot (valor pequeño, no compensa falta de anchor).
  static const double connectorVerticalInset = 4.0;

  // Ancho del ring estático que identifica la clase actual (tarea 2b).
  static const double currentRingStrokeWidth = 2.5;

  // Sombras
  static List<BoxShadow> shieldShadow = [
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        offset: const Offset(0, 5),
        blurRadius: 10),
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        offset: const Offset(0, 2),
        blurRadius: 3),
  ];

  static List<BoxShadow> labelCardShadow = [
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        offset: const Offset(0, 2),
        blurRadius: 8),
  ];

  // Helpers
  static Color hex(String h) {
    var s = h.replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.parse(s, radix: 16));
  }
}
