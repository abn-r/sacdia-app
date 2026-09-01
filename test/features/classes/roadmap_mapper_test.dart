import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/roadmap/data/roadmap_data.dart';
import 'package:sacdia_app/features/classes/presentation/roadmap/data/roadmap_mapper.dart';

ProgressiveClass _cls({
  required int id,
  required String name,
  required int clubTypeId,
  String? assetCode,
  int? minimumAge,
  int? enrollmentId,
  String? investitureStatus,
  int? overallProgress,
}) {
  return ProgressiveClass(
    id: id,
    name: name,
    clubTypeId: clubTypeId,
    assetCode: assetCode,
    minimumAge: minimumAge,
    enrollmentId: enrollmentId,
    investitureStatus: investitureStatus,
    overallProgress: overallProgress,
  );
}

void main() {
  group('buildRoadmapTracks', () {
    test('preserves enrollment id for enrolled roadmap nodes', () {
      const catalogClass = ProgressiveClass(
        id: 13,
        name: 'Guía',
        clubTypeId: 2,
        assetCode: 'CQ-06',
      );
      const enrolledClass = ProgressiveClass(
        id: 13,
        name: 'Guía',
        clubTypeId: 2,
        assetCode: 'CQ-06',
        enrollmentId: 901,
        investitureStatus: 'EXPIRED',
      );

      final tracks = buildRoadmapTracks(
        catalog: const [catalogClass],
        enrolled: const [enrolledClass],
      );

      expect(tracks.single.classes.single.enrollmentId, 901);
      expect(tracks.single.classes.single.status, ClassStatus.expired);
    });

    test('uses per-class minimumAge instead of the track age range', () {
      final tracks = buildRoadmapTracks(
        catalog: [
          _cls(
            id: 7,
            name: 'Amigo',
            clubTypeId: 2,
            assetCode: 'CQ-01',
            minimumAge: 10,
          ),
          _cls(
            id: 8,
            name: 'Compañero',
            clubTypeId: 2,
            assetCode: 'CQ-02',
            minimumAge: 11,
          ),
        ],
        enrolled: const [],
      );

      final classes = tracks.single.classes;
      expect(classes[0].age, 'Desde 10 años');
      expect(classes[0].minimumAge, 10);
      expect(classes[1].age, 'Desde 11 años');
      expect(classes[1].minimumAge, 11);
      expect(classes[0].age, isNot(contains('10 — 15')));
    });

    test('falls back to official age by asset_code when minimumAge is missing',
        () {
      final tracks = buildRoadmapTracks(
        catalog: [
          _cls(
            id: 7,
            name: 'Amigo',
            clubTypeId: 2,
            assetCode: 'CQ-01',
          ),
        ],
        enrolled: const [],
      );

      expect(tracks.single.classes.single.minimumAge, 10);
      expect(tracks.single.classes.single.age, 'Desde 10 años');
    });

    test('falls back to track age range when age and asset_code are missing',
        () {
      final tracks = buildRoadmapTracks(
        catalog: [
          _cls(id: 7, name: 'Amigo', clubTypeId: 2),
        ],
        enrolled: const [],
      );

      expect(tracks.single.classes.single.minimumAge, isNull);
      expect(tracks.single.classes.single.age, '10 — 15 años');
    });

    test('marks skipped classes as notTaken and later ones as upcoming', () {
      final catalog = [
        _cls(
          id: 1,
          name: 'Corderitos',
          clubTypeId: 1,
          assetCode: 'AV-01',
          minimumAge: 6,
        ),
        _cls(
          id: 7,
          name: 'Amigo',
          clubTypeId: 2,
          assetCode: 'CQ-01',
          minimumAge: 10,
        ),
        _cls(
          id: 8,
          name: 'Compañero',
          clubTypeId: 2,
          assetCode: 'CQ-02',
          minimumAge: 11,
        ),
        _cls(
          id: 20,
          name: 'Guía Mayor',
          clubTypeId: 3,
          assetCode: 'GM-01',
          minimumAge: 16,
        ),
      ];
      final enrolled = [
        _cls(
          id: 8,
          name: 'Compañero',
          clubTypeId: 2,
          assetCode: 'CQ-02',
          enrollmentId: 42,
          investitureStatus: 'PENDIENTE',
          overallProgress: 30,
        ),
      ];

      final tracks = buildRoadmapTracks(catalog: catalog, enrolled: enrolled);
      final byName = {
        for (final track in tracks)
          for (final item in track.classes) item.name: item,
      };

      expect(byName['Corderitos']!.status, ClassStatus.notTaken);
      expect(byName['Amigo']!.status, ClassStatus.notTaken);
      expect(byName['Compañero']!.status, ClassStatus.current);
      expect(byName['Compañero']!.progress, 30);
      expect(byName['Guía Mayor']!.status, ClassStatus.upcoming);
    });

    test('marks every class as upcoming when the user has no enrollments', () {
      final tracks = buildRoadmapTracks(
        catalog: [
          _cls(
            id: 7,
            name: 'Amigo',
            clubTypeId: 2,
            assetCode: 'CQ-01',
            minimumAge: 10,
          ),
          _cls(
            id: 8,
            name: 'Compañero',
            clubTypeId: 2,
            assetCode: 'CQ-02',
            minimumAge: 11,
          ),
        ],
        enrolled: const [],
      );

      expect(
        tracks.single.classes.map((c) => c.status),
        everyElement(ClassStatus.upcoming),
      );
    });

    test('marks invested enrollments as done', () {
      final tracks = buildRoadmapTracks(
        catalog: [
          _cls(
            id: 13,
            name: 'Guía',
            clubTypeId: 2,
            assetCode: 'CQ-06',
            minimumAge: 15,
          ),
        ],
        enrolled: [
          _cls(
            id: 13,
            name: 'Guía',
            clubTypeId: 2,
            assetCode: 'CQ-06',
            enrollmentId: 1,
            investitureStatus: 'INVESTIDO',
          ),
        ],
      );

      expect(tracks.single.classes.single.status, ClassStatus.done);
    });
  });
}
