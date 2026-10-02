import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_period.dart';

Camporee _camporee({
  required int id,
  required DateTime start,
  required DateTime end,
}) {
  return Camporee(
    camporeeId: id,
    name: 'Camporee $id',
    startDate: start,
    endDate: end,
    place: 'Campo',
    includesAdventurers: false,
    includesPathfinders: true,
    includesMasterGuides: false,
    active: true,
  );
}

void main() {
  final today = DateTime(2026, 10, 1, 15, 30);
  final open = _camporee(
    id: 1,
    start: DateTime(2026, 10, 3),
    end: DateTime(2026, 10, 5),
  );
  final endingToday = _camporee(
    id: 2,
    start: DateTime(2026, 9, 30),
    end: DateTime(2026, 10, 1, 23),
  );
  final endedYesterday = _camporee(
    id: 3,
    start: DateTime(2026, 8, 21),
    end: DateTime(2026, 9, 30),
  );
  final older = _camporee(
    id: 4,
    start: DateTime(2025, 8, 1),
    end: DateTime(2025, 8, 3),
  );

  test('un camporee que termina hoy sigue en la lista principal', () {
    final items = [endedYesterday, open, endingToday, older];

    expect(
      currentCamporees(items, today).map((item) => item.camporeeId),
      [1, 2],
    );
    expect(
      historicalCamporees(items, today).map((item) => item.camporeeId),
      [3, 4],
    );
  });
}
