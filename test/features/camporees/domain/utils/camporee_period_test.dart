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

  group('CamporeeTiming', () {
    final camporee = _camporee(
      id: 9,
      start: DateTime(2027, 2, 10),
      end: DateTime(2027, 2, 12),
    );

    test('counts the days until it starts', () {
      final timing = CamporeeTiming.of(camporee, DateTime(2026, 11, 6, 23, 59));
      expect(timing.kind, CamporeeTimingKind.upcoming);
      expect(timing.days, 96);
    });

    test('the day before is one day away', () {
      final timing = CamporeeTiming.of(camporee, DateTime(2027, 2, 9, 8));
      expect(timing.kind, CamporeeTimingKind.upcoming);
      expect(timing.days, 1);
    });

    test('tells the running day out of the total', () {
      final first = CamporeeTiming.of(camporee, DateTime(2027, 2, 10, 6));
      expect(first.kind, CamporeeTimingKind.ongoing);
      expect((first.day, first.totalDays), (1, 3));
      expect(first.endsToday, isFalse);

      final last = CamporeeTiming.of(camporee, DateTime(2027, 2, 12, 22));
      expect((last.day, last.totalDays), (3, 3));
      expect(last.endsToday, isTrue);
    });

    test('counts the days since it ended', () {
      final timing = CamporeeTiming.of(camporee, DateTime(2027, 4, 13));
      expect(timing.kind, CamporeeTimingKind.ended);
      expect(timing.days, 60);
    });

    test('an end before the start reads as a one-day camporee', () {
      final odd = _camporee(
        id: 10,
        start: DateTime(2027, 3, 5),
        end: DateTime(2027, 3, 4),
      );
      final timing = CamporeeTiming.of(odd, DateTime(2027, 3, 5));
      expect((timing.day, timing.totalDays), (1, 1));
      expect(timing.endsToday, isTrue);
    });
  });
}
