import '../../../../core/realtime/realtime_ref.dart';
import '../../../classes/presentation/providers/classes_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../honors/presentation/providers/honors_providers.dart';

/// Suelta la copia en memoria de los datos de servidor que sobreviven a un
/// borrado de disco por `keepAlive`.
///
/// Catálogos, actividades y miembros los invalida
/// [RealtimeResourceRegistry.invalidateAll]. Esto cubre el home, las clases
/// del usuario y el catálogo de especialidades, que ese registro no toca.
void invalidateSessionServerCaches(RealtimeRef ref) {
  ref.invalidate(dashboardNotifierProvider);
  ref.invalidate(userClassesProvider);
  ref.invalidate(userHonorsProvider);
  ref.invalidate(honorCategoriesProvider);
  ref.invalidate(honorsGroupedByCategoryProvider);
  ref.invalidate(allHonorsProvider);
}
