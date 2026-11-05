import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/classes_providers.dart';
import 'class_catalog.dart';

/// «Clases por club»: the enabled catalog (`allClassesProvider`) merged with
/// the user's enrollments of every year (`userClassesProvider`). Both are
/// cached providers, so this adds no request when Mi Camino already loaded.
final classCatalogProvider =
    FutureProvider.autoDispose<List<ClassCatalogSection>>((ref) async {
  final results = await Future.wait([
    ref.watch(allClassesProvider.future),
    ref.watch(userClassesProvider.future),
  ]);
  return buildClassCatalog(catalog: results[0], enrolled: results[1]);
});

/// Pull-to-refresh: both sources go back to the network.
Future<void> refreshClassCatalog(WidgetRef ref) async {
  ref.invalidate(allClassesProvider);
  ref.invalidate(userClassesProvider);
  try {
    await ref.read(classCatalogProvider.future);
  } catch (_) {
    // The error stays in classCatalogProvider and the view shows it.
  }
}
