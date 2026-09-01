import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_club_type.dart';

Camporee _camporee({
  required int id,
  bool adventurers = false,
  bool pathfinders = false,
  bool masterGuides = false,
}) {
  return Camporee(
    camporeeId: id,
    name: 'Camporee $id',
    startDate: DateTime(2026, 8, 21),
    endDate: DateTime(2026, 8, 23),
    place: 'Campo',
    includesAdventurers: adventurers,
    includesPathfinders: pathfinders,
    includesMasterGuides: masterGuides,
    active: true,
  );
}

void main() {
  final adventurersOnly = _camporee(id: 1, adventurers: true);
  final pathfindersOnly = _camporee(id: 2, pathfinders: true);
  final mixed = _camporee(id: 3, adventurers: true, pathfinders: true);
  final masterGuidesOnly = _camporee(id: 4, masterGuides: true);
  final all = [adventurersOnly, pathfindersOnly, mixed, masterGuidesOnly];

  group('filterCamporeesForClubType', () {
    test('should keep adventurer and mixed camporees for Aventureros', () {
      expect(
        filterCamporeesForClubType(all, CamporeeClubTypeIds.adventurers)
            .map((c) => c.camporeeId),
        [1, 3],
      );
    });

    test('should keep pathfinder and mixed camporees for Conquistadores', () {
      expect(
        filterCamporeesForClubType(all, CamporeeClubTypeIds.pathfinders)
            .map((c) => c.camporeeId),
        [2, 3],
      );
    });

    test('should keep only master-guide camporees for Guías Mayores', () {
      expect(
        filterCamporeesForClubType(all, CamporeeClubTypeIds.masterGuides)
            .map((c) => c.camporeeId),
        [4],
      );
    });

    test('should return the full list when there is no section club type', () {
      expect(filterCamporeesForClubType(all, null), all);
    });

    test('should return an empty list for an unknown club type id', () {
      expect(filterCamporeesForClubType(all, 99), isEmpty);
    });
  });

  group('resolveCamporeeListClubTypeId', () {
    test('should prefer the numeric club type id', () {
      expect(
        resolveCamporeeListClubTypeId(
            CamporeeClubTypeIds.pathfinders, 'Aventureros'),
        CamporeeClubTypeIds.pathfinders,
      );
    });

    test('should resolve Aventureros from the club type name', () {
      expect(
        resolveCamporeeListClubTypeId(null, 'Aventureros'),
        CamporeeClubTypeIds.adventurers,
      );
    });
  });
}
