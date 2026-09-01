// Mapper que convierte catálogo + clases inscritas (dominio) a List<TrackData>
// (modelo del roadmap visual).
//
// Estrategia de merge:
//   1. Iterar el catálogo completo (ordenado por display_order en el backend).
//   2. Para cada clase del catálogo, buscar en el Map de inscritas por id.
//   3. Si la encuentra → usar datos de la inscripción (investitureStatus,
//      overallProgress).
//   4. Si no la encuentra → notTaken (quedó atrás del frente de inscripción)
//      o upcoming (aún por cursar).
//
// Reglas de status:
//   done     → inscrita y investitureStatus == 'INVESTIDO'
//   current  → inscrita y no investida (PENDIENTE u otro estado activo)
//   expired  → inscrita y investitureStatus == 'EXPIRED'
//   notTaken → no inscrita y hay una clase posterior en el camino con
//              inscripción (no la cursó)
//   upcoming → no inscrita y no hay progreso posterior (le falta cursarla)
//
// Edad del nodo: ProgressiveClass.minimumAge (classes.minimum_age). Si falta,
// se usa el mapa oficial por asset_code. Último recurso: rango del track.
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

/// Edad mínima oficial JA por `asset_code` cuando el catálogo no envía
/// `minimum_age`. Coincide con el seed histórico de Pathfinders/Adventurers.
const _minAgeByAsset = <String, int>{
  'AV-01': 6,
  'AV-02': 6,
  'AV-03': 7,
  'AV-04': 7,
  'AV-05': 8,
  'AV-06': 9,
  'CQ-01': 10,
  'CQ-02': 11,
  'CQ-03': 12,
  'CQ-04': 13,
  'CQ-05': 14,
  'CQ-06': 15,
  'GM-01': 16,
  'GM-02': 18,
  'GM-03': 21,
};

int? _resolveMinimumAge(ProgressiveClass cls) {
  if (cls.minimumAge != null) return cls.minimumAge;
  final code = cls.assetCode?.toUpperCase();
  if (code == null || code.isEmpty) return null;
  return _minAgeByAsset[code];
}

String _formatMinimumAge(int? age, {required String fallback}) {
  if (age == null) return fallback;
  return 'Desde $age años';
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
/// el roadmap muestra el camino completo con todas las clases
/// [ClassStatus.upcoming].
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

  final orderedCatalog = <ProgressiveClass>[
    for (final typeId in [1, 2, 3]) ...?catalogByType[typeId],
  ];
  final statusById = _deriveStatuses(orderedCatalog, enrolledById);

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
      final minimumAge = _resolveMinimumAge(catalogCls);

      return ClassItem(
        id: effectiveCls.id.toString(),
        name: effectiveCls.name,
        age: _formatMinimumAge(minimumAge, fallback: meta.ageRange),
        minimumAge: minimumAge,
        img: _resolveAsset(effectiveCls.assetCode, meta.assetPrefix, position),
        status: statusById[catalogCls.id] ?? ClassStatus.upcoming,
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

/// Deriva el estado de cada clase recorriendo el catálogo en orden canónico.
///
/// El "frente" es el último índice con inscripción. Lo anterior no inscrito
/// es [ClassStatus.notTaken]; lo posterior no inscrito es
/// [ClassStatus.upcoming].
Map<int, ClassStatus> _deriveStatuses(
  List<ProgressiveClass> orderedCatalog,
  Map<int, ProgressiveClass> enrolledById,
) {
  var lastReachedIndex = -1;
  final enrolledStatus = <int, ClassStatus>{};

  for (var i = 0; i < orderedCatalog.length; i++) {
    final enrolled = enrolledById[orderedCatalog[i].id];
    if (enrolled == null) continue;
    lastReachedIndex = i;
    enrolledStatus[orderedCatalog[i].id] =
        _deriveEnrolledStatus(enrolled.investitureStatus);
  }

  final result = <int, ClassStatus>{};
  for (var i = 0; i < orderedCatalog.length; i++) {
    final id = orderedCatalog[i].id;
    final enrolled = enrolledStatus[id];
    if (enrolled != null) {
      result[id] = enrolled;
      continue;
    }
    result[id] =
        i < lastReachedIndex ? ClassStatus.notTaken : ClassStatus.upcoming;
  }
  return result;
}

/// Deriva el [ClassStatus] desde el valor de investitureStatus del backend.
///
/// Valores observados: null, 'PENDIENTE', 'INVESTIDO', 'EXPIRED'.
/// Cualquier estado activo no-investido se trata como [ClassStatus.current].
/// Una inscripción sin status se trata como current (ya está cursando).
ClassStatus _deriveEnrolledStatus(String? investitureStatus) {
  if (investitureStatus == null) return ClassStatus.current;
  final normalized = investitureStatus.toUpperCase();
  if (normalized == 'INVESTIDO') return ClassStatus.done;
  if (normalized == 'EXPIRED') return ClassStatus.expired;
  return ClassStatus.current;
}
