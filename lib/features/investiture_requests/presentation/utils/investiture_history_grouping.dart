/// Elementos de una misma clase dentro de un año.
class ClassGroup<T> {
  const ClassGroup({
    required this.classId,
    required this.className,
    required this.items,
  });

  final int classId;
  final String? className;
  final List<T> items;
}

/// Clases de un año eclesiástico.
class YearGroup<T> {
  const YearGroup({required this.yearId, required this.classes});

  final int yearId;
  final List<ClassGroup<T>> classes;

  int get count => classes.fold(0, (sum, group) => sum + group.items.length);
}

/// Agrupa por año eclesiástico (el más reciente primero) y, dentro, por clase
/// (en el orden de progresión de las clases, por id). Conserva el orden de entrada dentro
/// de cada clase.
List<YearGroup<T>> groupByYearAndClass<T>(
  Iterable<T> items, {
  required int Function(T item) yearOf,
  required int Function(T item) classIdOf,
  required String? Function(T item) classNameOf,
}) {
  final byYear = <int, Map<int, List<T>>>{};
  final names = <int, String?>{};
  for (final item in items) {
    final classId = classIdOf(item);
    byYear
        .putIfAbsent(yearOf(item), () => <int, List<T>>{})
        .putIfAbsent(classId, () => <T>[])
        .add(item);
    final name = classNameOf(item)?.trim();
    if (name != null && name.isNotEmpty) names[classId] ??= name;
  }

  final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final year in years)
      YearGroup<T>(
        yearId: year,
        classes: (byYear[year]!.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key)))
            .map(
              (entry) => ClassGroup<T>(
                classId: entry.key,
                className: names[entry.key],
                items: entry.value,
              ),
            )
            .toList(growable: false),
      ),
  ];
}
