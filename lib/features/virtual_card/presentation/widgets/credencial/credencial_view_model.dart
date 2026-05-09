import '../../../domain/entities/virtual_card.dart';
import 'credencial_tokens.dart';

/// Lightweight view-model that bridges [VirtualCard] to the data the
/// immersive credential card (CredencialCard / CredencialQrFullscreen) needs.
///
/// Section detection uses `.contains()` on the combined lowercased
/// clubName + roleCode + sectionName strings, matching the pattern already
/// used by `_clubFallbackAsset` in virtual_card_face.dart:
///   avent*          → AV
///   conq*/conquistador* → CQ
///   guia*/mayor*    → GM
///   unknown / null  → CQ (default)
class CredencialViewModel {
  final String nombre;
  final String cargo; // role label (e.g. 'Conquistador', 'Director')
  final String etapa; // currentClass or empty — not yet in VirtualCard
  final String club; // clubName or empty
  final String clubCorto; // 3-letter acronym
  final String sectionFull; // sectionName full (e.g. 'Guías Mayores')
  final String qrData; // token string — the actual QR payload
  final String folio; // derived short folio for display
  final String idCorto; // last 8 chars of cardIdShort / token for footer
  final DateTime fechaVencimiento;
  final String anioEclesiastico;
  final String estado; // 'Activo' | 'Suspendido'
  final String? fotoUrl;
  final SeccionCode seccion;

  // Fields with no VirtualCard source yet — shown as empty / hidden
  final String tipoSangre; // TODO: plumb from backend medical profile
  final String emergenciaNombre; // TODO: plumb from emergency contact
  final String emergenciaTel;
  final String emergenciaRelacion;

  CredencialViewModel({
    required this.nombre,
    required this.cargo,
    required this.etapa,
    required this.club,
    required this.clubCorto,
    required this.sectionFull,
    required this.qrData,
    required this.folio,
    required this.idCorto,
    required this.fechaVencimiento,
    required this.anioEclesiastico,
    required this.estado,
    required this.seccion,
    this.fotoUrl,
    this.tipoSangre = '',
    this.emergenciaNombre = '',
    this.emergenciaTel = '',
    this.emergenciaRelacion = '',
  });

  /// Si el clubName es muy corto (≤4 chars) probablemente es un acrónimo.
  /// En ese caso preferimos mostrar el sectionName completo donde el espacio
  /// lo permita.
  bool get clubLooksLikeAcronym => club.trim().length <= 4;

  /// Etiqueta principal de identidad para el chip primario.
  /// Prioriza cargo (rol del miembro). Si no existe, usa sectionFull.
  String get identidadPrimaria {
    if (cargo.trim().isNotEmpty) return cargo;
    if (sectionFull.trim().isNotEmpty) return sectionFull;
    return '';
  }

  bool get hasEmergencia =>
      emergenciaNombre.isNotEmpty && emergenciaTel.isNotEmpty;

  String get iniciales {
    final parts = nombre.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Creates a [CredencialViewModel] from a [VirtualCard].
  ///
  /// All mappings are documented inline. Fields not yet exposed by the
  /// VirtualCard entity are left as empty strings / sensible defaults and
  /// annotated with TODO for the next backend phase.
  factory CredencialViewModel.fromVirtualCard(VirtualCard card) {
    final seccion = _seccionFromCard(card);
    final qrToken = card.qrToken ?? '';
    final expiresAt =
        card.qrExpiresAt ?? DateTime.now().add(const Duration(days: 365));

    return CredencialViewModel(
      // ── Identity ──────────────────────────────────────────────────────────
      nombre: card.fullName.isNotEmpty ? card.fullName : 'Miembro',
      cargo: card.roleLabel ?? '',
      etapa: card.currentClass ?? '',
      club: card.clubName ?? '',
      clubCorto: _clubCorto(card.clubName, card.sectionName),
      sectionFull: card.sectionName ?? '',

      // ── QR payload ────────────────────────────────────────────────────────
      qrData: qrToken,
      folio: _folio(card),
      idCorto: _idCorto(card),

      // ── Dates & status ────────────────────────────────────────────────────
      fechaVencimiento: expiresAt,
      anioEclesiastico: DateTime.now().year.toString(),
      estado: card.isActive ? 'Activo' : 'Suspendido',

      // ── Visual ────────────────────────────────────────────────────────────
      seccion: seccion,
      fotoUrl: card.photoUrl,

      tipoSangre: card.bloodType ?? '',
      emergenciaNombre: card.emergencyContact?.name ?? '',
      emergenciaTel: card.emergencyContact?.phone ?? '',
      emergenciaRelacion: card.emergencyContact?.relationship ?? '',
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Derives [SeccionCode] from the combined club / role / section strings.
  ///
  /// Same substring-matching strategy used by `_clubFallbackAsset` in
  /// `virtual_card_face.dart`. Order matters: AV before CQ because
  /// "aventurero" doesn't overlap with "conq", but be explicit anyway.
  static SeccionCode _seccionFromCard(VirtualCard card) {
    final source =
        '${card.clubName ?? ''} ${card.roleCode ?? ''} ${card.sectionName ?? ''}'
            .toLowerCase();
    if (source.contains('avent')) {
      return SeccionCode.AV;
    }
    if (source.contains('guia') ||
        source.contains('guía') ||
        source.contains('mayor')) {
      return SeccionCode.GM;
    }
    if (source.contains('conq')) {
      return SeccionCode.CQ;
    }
    // Default to CQ — the most common section in SACDIA clubs.
    return SeccionCode.CQ;
  }

  /// Derives a 3-letter uppercase acronym from [clubName].
  ///
  /// Takes the first letter of each word (max 3). Falls back to the first
  /// 3 letters of [sectionName], then 'CLB'.
  static String _clubCorto(String? clubName, String? sectionName) {
    if (clubName != null && clubName.trim().isNotEmpty) {
      final words = clubName
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      final acronym = words.take(3).map((w) => w[0].toUpperCase()).join();
      if (acronym.isNotEmpty) return acronym;
    }
    if (sectionName != null && sectionName.trim().length >= 3) {
      return sectionName.substring(0, 3).toUpperCase();
    }
    return 'CLB';
  }

  /// Derives the display folio string.
  ///
  /// Prefers the structured `cardIdShort` from the entity. Falls back to the
  /// last 8 chars of the QR token formatted as SAC-YYYY-XXXX-XXXX.
  static String _folio(VirtualCard card) {
    final id = card.cardIdShort;
    if (id != null && id.trim().isNotEmpty) {
      return 'SAC-${DateTime.now().year}-${id.trim().toUpperCase()}';
    }
    final token = card.qrToken ?? '';
    final year =
        (card.qrExpiresAt ?? DateTime.now().add(const Duration(days: 365)))
            .year;
    final suffix = token.length >= 8
        ? token.substring(token.length - 8).toUpperCase()
        : token.toUpperCase().padLeft(8, '0');
    return 'SAC-$year-${suffix.substring(0, 4)}-${suffix.substring(4)}';
  }

  /// Last 8 chars of cardIdShort (or qrToken) for the footer version label.
  static String _idCorto(VirtualCard card) {
    final id = card.cardIdShort;
    if (id != null && id.trim().isNotEmpty) {
      final trimmed = id.trim();
      return trimmed.length >= 8
          ? trimmed.substring(trimmed.length - 8).toLowerCase()
          : trimmed.toLowerCase().padLeft(8, '0');
    }
    final token = card.qrToken ?? '';
    if (token.length >= 8) {
      return token.substring(token.length - 8).toLowerCase();
    }
    return token.toLowerCase().padLeft(8, '0');
  }
}
