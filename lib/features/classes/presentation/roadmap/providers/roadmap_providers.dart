// Providers Riverpod para el roadmap de clases.
//
// [roadmapTracksProvider] combina [allClassesProvider] (catálogo completo) con
// [userClassesProvider] (clases inscritas con progreso) y construye los
// List<TrackData> del roadmap via [buildRoadmapTracks].
//
// Las dos llamadas de red se lanzan en paralelo con Future.wait para minimizar
// la latencia total del roadmap.
//
// autoDispose: se libera cuando el tab Roadmap no está visible.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/classes_providers.dart';
import '../data/roadmap_data.dart';
import '../data/roadmap_mapper.dart';

/// Provider que expone los tracks del roadmap.
///
/// Combina el catálogo completo ([allClassesProvider]) con el progreso real del
/// usuario ([userClassesProvider]):
/// - Clases inscritas → status derivado de investitureStatus (done/current).
/// - Clases solo en catálogo → status locked.
///
/// Retorna [AsyncValue<List<TrackData>>] con los mismos estados de ciclo de
/// vida (loading / error / data) que los providers subyacentes.
/// El estado vacío se emite solo si el catálogo está vacío (edge case).
final roadmapTracksProvider =
    FutureProvider.autoDispose<List<TrackData>>((ref) async {
  // Lanzar ambas peticiones en paralelo para minimizar latencia.
  // userClassesProvider usa keepAlive, así que si ya está cargado no hay
  // segunda petición de red — simplemente reutiliza el caché en memoria.
  final results = await Future.wait([
    ref.watch(allClassesProvider.future),
    ref.watch(userClassesProvider.future),
  ]);

  final catalog = results[0];
  final enrolled = results[1];

  return buildRoadmapTracks(catalog: catalog, enrolled: enrolled);
});
