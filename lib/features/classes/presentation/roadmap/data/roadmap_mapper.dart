// Mapper que convierte catálogo + clases inscritas (dominio) a List<TrackData>
// (modelo del roadmap visual).
//
// Estrategia de merge:
//   1. Iterar el catálogo completo (ordenado por display_order en el backend).
//   2. Para cada clase del catálogo, buscar en el Map de inscritas por id.
//   3. Si la encuentra → usar datos de la inscripción (investitureStatus, overallProgress).
//   4. Si no la encuentra → marcar como locked.
//
// Reglas de status:
//   done    → inscrita y investitureStatus == 'INVESTIDO'
//   current → inscrita y investitureStatus != null && != 'INVESTIDO'
//   locked  → no inscrita (o inscrita sin investitureStatus, edge case)
//
// Agrupación por clubTypeId:
//   1 → Aventureros
//   2 → Conquistadores
//   3 → Guías Mayores
//
// Orden: el backend ya retorna el catálogo ordenado por
//   (club_type_id ASC, display_order ASC) — se preserva el orden de llegada.
//
// Imágenes: fuente de verdad es ProgressiveClass.assetCode (e.g. "AV-01").
// Cuando el campo es null (backend no desplegado o clase sin código), se cae
// al fallback ordinal por posición dentro del track. El fallback es deuda
// técnica heredada — se puede eliminar cuando TODAS las clases del catálogo
// tengan assetCode poblado en el backend.
// va_node.dart usa Image.asset, no Image.network — _resolveAsset SIEMPRE
// devuelve un path de asset local, nunca una URL HTTP.

import '../../../domain/entities/progressive_class.dart';
import 'roadmap_data.dart';

/// Asset local fallback por track y posición ordinal (1-based).
/// Asume la convención AV-01..06, CQ-01..06, GM-01..03.
/// Mantenido como fallback hasta que TODAS las clases del catálogo
/// tengan [ProgressiveClass.assetCode] poblado en el backend.
String _localAsset(String prefix, int position) {
  final padded = position.toString().padLeft(2, '0');
  return 'assets/img/logos-clases/$prefix-$padded.png';
}

/// Resuelve el path del asset local para un nodo del roadmap.
///
/// Preferencia: [assetCode] del backend (e.g. "AV-01") → fallback ordinal.
/// Siempre retorna un path de asset local (nunca URL HTTP).
String _resolveAsset(String? assetCode, String prefix, int position) {
  if (assetCode != null && assetCode.isNotEmpty) {
    return 'assets/img/logos-clases/$assetCode.png';
  }
  return _localAsset(prefix, position);
}

/// Metadatos estáticos de cada track (colores, rango de edad, etc.)
const _trackMeta = {
  1: _TrackMeta(
    track: 'Aventureros',
    ageRange: '6 — 9 años',
    accent: '#4FB37C',
    soft: '#E8F4EC',
    kind: 'av',
    assetPrefix: 'AV',
  ),
  2: _TrackMeta(
    track: 'Conquistadores',
    ageRange: '10 — 15 años',
    accent: '#3D6FA5',
    soft: '#EAF1F8',
    kind: 'cq',
    assetPrefix: 'CQ',
  ),
  3: _TrackMeta(
    track: 'Guías Mayores',
    ageRange: '16+ años',
    accent: '#C99036',
    soft: '#FCF1DC',
    kind: 'gm',
    assetPrefix: 'GM',
  ),
};

class _TrackMeta {
  final String track;
  final String ageRange;
  final String accent;
  final String soft;
  final String kind;
  final String assetPrefix;

  const _TrackMeta({
    required this.track,
    required this.ageRange,
    required this.accent,
    required this.soft,
    required this.kind,
    required this.assetPrefix,
  });
}

/// Construye los tracks del roadmap mergeando catálogo completo con progreso
/// real del usuario.
///
/// [catalog] — todas las clases del sistema (Aventureros, Conquistadores,
/// Guías Mayores), sin datos de progreso. Viene ordenado por
/// (club_type_id ASC, display_order ASC) desde el backend.
///
/// [enrolled] — clases en las que el usuario está inscrito, con
/// [ProgressiveClass.investitureStatus] y [ProgressiveClass.overallProgress].
///
/// Comportamiento cuando el usuario no tiene clases inscritas:
/// el roadmap muestra el camino completo con todas las clases [ClassStatus.locked].
///
/// Retorna lista vacía solo si [catalog] está vacío.
List<TrackData> buildRoadmapTracks({
  required List<ProgressiveClass> catalog,
  required List<ProgressiveClass> enrolled,
}) {
  // Índice O(1) de clases inscritas por id.
  final Map<int, ProgressiveClass> enrolledById = {
    for (final cls in enrolled) cls.id: cls,
  };

  // Agrupar catálogo por clubTypeId preservando orden de llegada del backend.
  final Map<int, List<ProgressiveClass>> catalogByType = {};
  for (final cls in catalog) {
    catalogByType.putIfAbsent(cls.clubTypeId, () => []).add(cls);
  }

  // Emitir tracks en orden canónico: Aventureros (1) → Conquistadores (2) → GM (3).
  final result = <TrackData>[];
  for (final typeId in [1, 2, 3]) {
    final meta = _trackMeta[typeId];
    if (meta == null) continue;
    final classes = catalogByType[typeId] ?? [];
    if (classes.isEmpty) continue;

    final items = classes.asMap().entries.map((e) {
      final position = e.key + 1; // 1-based para fallback de asset local
      final catalogCls = e.value;

      // Si el usuario tiene esta clase inscrita, usar sus datos de progreso.
      final enrolledCls = enrolledById[catalogCls.id];
      final effectiveCls = enrolledCls ?? catalogCls;

      return ClassItem(
        id: effectiveCls.id.toString(),
        name: effectiveCls.name,
        // ProgressiveClass no tiene campo de edad — usamos el rango del track.
        age: meta.ageRange,
        img: _resolveAsset(effectiveCls.assetCode, meta.assetPrefix, position),
        status: enrolledCls != null
            ? _deriveStatus(enrolledCls.investitureStatus)
            : ClassStatus.locked,
        enrollmentId: enrolledCls?.enrollmentId,
        progress: enrolledCls?.overallProgress?.toDouble(),
      );
    }).toList();

    result.add(TrackData(
      track: meta.track,
      ageRange: meta.ageRange,
      accent: meta.accent,
      soft: meta.soft,
      kind: meta.kind,
      classes: items,
    ));
  }

  return result;
}

/// Deriva el [ClassStatus] desde el valor de investitureStatus del backend.
///
/// Valores observados: null, 'PENDIENTE', 'INVESTIDO', 'EXPIRED'.
/// Cualquier estado activo no-investido se trata como [ClassStatus.current].
ClassStatus _deriveStatus(String? investitureStatus) {
  if (investitureStatus == null) return ClassStatus.locked;
  final normalized = investitureStatus.toUpperCase();
  if (normalized == 'INVESTIDO') return ClassStatus.done;
  if (normalized == 'EXPIRED') return ClassStatus.expired;
  return ClassStatus.current;
}
