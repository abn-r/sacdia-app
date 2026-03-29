import 'package:flutter/material.dart';

/// SACDIA Design System - Paleta "Scout Vibrante"
///
/// Estilo: Duolingo (gamificación) + Apple Health (minimalista)
/// Fondos blancos, acentos vibrantes, progreso como protagonista.
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════
  // COLORES PRINCIPALES
  // ═══════════════════════════════════════════════════════════

  /// SACDIA Red - Botones principales, AppBar, enlaces, navegación
  static const Color primary = Color(0xFFF06151);

  /// Red 100 - Badges, chips, fondos de selección, hover
  static const Color primaryLight = Color(0xFFFDE8E6);

  /// Red 800 - Texto énfasis, estados pressed
  static const Color primaryDark = Color(0xFFD94A3B);

  /// Red 50 - Fondo muy sutil para selecciones
  static const Color primarySurface = Color(0xFFFFF1EF);

  // ═══════════════════════════════════════════════════════════
  // COLORES SECUNDARIOS
  // ═══════════════════════════════════════════════════════════

  /// SACDIA Green - Éxito, completado, progreso, naturaleza/scout
  static const Color secondary = Color(0xFF4FBF9F);

  /// Green 100 - Badge completado, fondo success
  static const Color secondaryLight = Color(0xFFE0F5EF);

  /// Green 800 - Texto success
  static const Color secondaryDark = Color(0xFF2D8A70);

  // ═══════════════════════════════════════════════════════════
  // COLOR DE ACENTO
  // ═══════════════════════════════════════════════════════════

  /// SACDIA Yellow - Estrellas, logros, recompensas, en-progreso
  static const Color accent = Color(0xFFFBBD5E);

  /// Yellow 100 - Badge en-progreso
  static const Color accentLight = Color(0xFFFFF4E0);

  /// Yellow 800 - Texto warning
  static const Color accentDark = Color(0xFFB8862B);

  // ═══════════════════════════════════════════════════════════
  // COLOR DE ERROR
  // ═══════════════════════════════════════════════════════════

  /// Rojo intenso - Errores, destructivo, alertas (diferenciado del primary)
  static const Color error = Color(0xFFDC2626);

  /// Red 100 - Badge error
  static const Color errorLight = Color(0xFFFEE2E2);

  /// Red 900 - Texto error
  static const Color errorDark = Color(0xFF991B1B);

  // ═══════════════════════════════════════════════════════════
  // SUPERFICIES Y FONDOS - LIGHT MODE
  // ═══════════════════════════════════════════════════════════

  /// Fondo principal de todas las pantallas
  static const Color lightBackground = Color(0xFFFFFFFF);

  /// Cards, modales, bottom sheets
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Secciones alternas, fondos secundarios
  static const Color lightSurfaceVariant = Color(0xFFF8FAFC);

  /// Bordes de cards, dividers
  static const Color lightBorder = Color(0xFFE2E8F0);

  /// Bordes muy sutiles, separadores internos
  static const Color lightBorderLight = Color(0xFFF1F5F9);

  /// Divider (alias para compatibilidad)
  static const Color lightDivider = Color(0xFFE2E8F0);

  // ═══════════════════════════════════════════════════════════
  // TEXTO - LIGHT MODE
  // ═══════════════════════════════════════════════════════════

  /// Títulos, texto principal
  static const Color lightText = Color(0xFF0F172A);

  /// Subtítulos, descripciones
  static const Color lightTextSecondary = Color(0xFF64748B);

  /// Placeholders, hints, metadata
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // ═══════════════════════════════════════════════════════════
  // SUPERFICIES Y FONDOS - DARK MODE
  // True Black / OLED-optimized — sin undertone azul
  // ═══════════════════════════════════════════════════════════

  /// Fondo principal dark — negro puro OLED
  static const Color darkBackground = Color(0xFF000000);

  /// Cards, modales dark — elevación 1dp sobre negro
  static const Color darkSurface = Color(0xFF1A1A1A);

  /// Secciones alternas dark — elevación 2dp
  static const Color darkSurfaceVariant = Color(0xFF252525);

  /// Bordes dark — sutil, neutral
  static const Color darkBorder = Color(0xFF303030);

  /// Divider dark (alias)
  static const Color darkDivider = Color(0xFF303030);

  // ═══════════════════════════════════════════════════════════
  // TEXTO - DARK MODE
  // ═══════════════════════════════════════════════════════════

  /// Texto principal dark — blanco suave, no puro (menos fatiga visual)
  static const Color darkText = Color(0xFFF2F2F2);

  /// Texto secundario dark — gris neutro, sin tinte azul
  static const Color darkTextSecondary = Color(0xFF8C8C8C);

  /// Texto terciario dark — gris más oscuro para hints/metadata
  static const Color darkTextTertiary = Color(0xFF5C5C5C);

  // ═══════════════════════════════════════════════════════════
  // COLORES DE ESTADO (alias semánticos)
  // ═══════════════════════════════════════════════════════════

  static const Color success = Color(0xFF4FBF9F);
  static const Color warning = Color(0xFFFBBD5E);
  static const Color info = Color(0xFF2EA0DA);

  // ═══════════════════════════════════════════════════════════
  // STATUS BADGE — "enviado/sent" — dark-mode aware
  // ═══════════════════════════════════════════════════════════

  /// Fondo del badge "enviado" en light mode
  static const Color statusInfoBgLight = Color(0xFFEFF6FF);

  /// Fondo del badge "enviado" en dark mode
  static const Color statusInfoBgDark = Color(0xFF1E293B);

  /// Texto/ícono del badge "enviado" en light mode
  static const Color statusInfoText = Color(0xFF1D4ED8);

  /// Texto/ícono del badge "enviado" en dark mode
  static const Color statusInfoTextDark = Color(0xFF60A5FA);

  // ═══════════════════════════════════════════════════════════
  // COLORES DE MARCA SACDIA (legacy, mantener para branding)
  // ═══════════════════════════════════════════════════════════

  static const Color sacRed = Color(0xFFF06151);
  static const Color sacBlue = Color(0xFF2EA0DA);
  static const Color sacYellow = Color(0xFFFBBD5E);
  static const Color sacGreen = Color(0xFF4FBF9F);
  static const Color sacBlack = Color(0xFF183651);
  static const Color sacWhite = Color(0xFFE1E6E7);
  static const Color sacGrey = Color.fromARGB(255, 225, 184, 184);
  static const Color sacGreenLight = Color(0xFF43A78A);

  // ═══════════════════════════════════════════════════════════
  // COLORES DE CLASES (tradición scout - NO cambiar)
  // ═══════════════════════════════════════════════════════════

  // Aventureros
  static const Color colorCorderitos = Color(0xFF70C1DC);
  static const Color colorCastores = Color(0xFF3D7734);
  static const Color colorAbejas = Color(0xFFF5D631);
  static const Color colorRayos = Color(0xFFDB563F);
  static const Color colorConstructores = Color(0xFF284376);
  static const Color colorManos = Color(0xFF8B2E38);

  // Conquistadores
  static const Color colorAmigo = Color(0xFF2EA0DA);
  static const Color colorCompanero = Color(0xFFF06151);
  static const Color colorExplorador = Color(0xFF4FBF9F);
  static const Color colorOrientador = Color(0xFF9FB9B1);
  static const Color colorViajero = Color(0xFFAE69BA);
  static const Color colorGuia = Color(0xFFFBBD5E);

  // Guías Mayores
  static const Color colorGuiaMayor = Color(0xFF023682);
  static const Color colorGuiaAvanzado = Color(0xFF023682);
  static const Color colorGuiaInstructor = Color(0xFF023682);

  // ═══════════════════════════════════════════════════════════
  // COLORES DE CATEGORÍAS DE HONORES
  // ═══════════════════════════════════════════════════════════

  static const Color catAdra = Color(0xFFE53935);
  static const Color catagropecuarias = Color(0xFF8BC34A);
  static const Color catCienciasSalud = Color(0xFF0288D1);
  static const Color catDomesticas = Color(0xFFFF8F00);
  static const Color catHabilidadesManuales = Color(0xFF6D4C41);
  static const Color catMisioneras = Color(0xFF7B1FA2);
  static const Color catNaturaleza = Color(0xFF2E7D32);
  static const Color catProfesionales = Color(0xFF37474F);
  static const Color catRecreativas = Color(0xFFE91E63);

  // ═══════════════════════════════════════════════════════════
  // HELPER: Resolución de color por nombre de clase progresiva
  // ═══════════════════════════════════════════════════════════

  /// Devuelve el color de marca de una clase progresiva por nombre.
  /// Retorna [primary] si el nombre no está en el mapa.
  static Color classColor(String name) => _classColorMap[name] ?? primary;

  /// Devuelve la ruta del asset local del logo de la clase, o null si no existe.
  static String? classLogoAsset(String name) => _classLogoMap[name];

  static const Map<String, String> _classLogoMap = {
    // Aventureros
    'Corderitos': 'assets/img/logos-clases/AV-01.png',
    'Aves Madrugadoras': 'assets/img/logos-clases/AV-02.png',
    'Abejitas Industriosas': 'assets/img/logos-clases/AV-03.png',
    'Rayos de Sol': 'assets/img/logos-clases/AV-04.png',
    'Constructores': 'assets/img/logos-clases/AV-05.png',
    'Manos Ayudadoras': 'assets/img/logos-clases/AV-06.png',
    // Conquistadores
    'Amigo': 'assets/img/logos-clases/CQ-01.png',
    'Compañero': 'assets/img/logos-clases/CQ-02.png',
    'Explorador': 'assets/img/logos-clases/CQ-03.png',
    'Orientador': 'assets/img/logos-clases/CQ-04.png',
    'Viajero': 'assets/img/logos-clases/CQ-05.png',
    'Guía': 'assets/img/logos-clases/CQ-06.png',
    // Guías Mayores
    'Guía Mayor': 'assets/img/logos-clases/GM-01.png',
    'Guía Avanzado': 'assets/img/logos-clases/GM-02.png',
    'Guía Instructor': 'assets/img/logos-clases/GM-03.png',
  };

  static const Map<String, Color> _classColorMap = {
    // Aventureros
    'Corderitos': colorCorderitos,
    'Aves Madrugadoras': colorCastores,
    'Abejitas Industriosas': colorAbejas,
    'Rayos de Sol': colorRayos,
    'Constructores': colorConstructores,
    'Manos Ayudadoras': colorManos,
    // Conquistadores
    'Amigo': colorAmigo,
    'Compañero': colorCompanero,
    'Explorador': colorExplorador,
    'Orientador': colorOrientador,
    'Viajero': colorViajero,
    'Guía': colorGuia,
    // Guías Mayores
    'Guía Mayor': colorGuiaMayor,
  };

  // ═══════════════════════════════════════════════════════════
  // COMPATIBILIDAD - Nombres antiguos mapeados a nuevos
  // Estos se eliminarán cuando se rediseñen todas las pantallas
  // ═══════════════════════════════════════════════════════════

  @Deprecated('Usar AppColors.primary')
  static const Color primaryBlue = primary;

  @Deprecated('Usar AppColors.secondary')
  static const Color secondaryTeal = secondary;

  @Deprecated('Usar AppColors.secondaryDark')
  static const Color secondaryDark2 = secondaryDark;
}
