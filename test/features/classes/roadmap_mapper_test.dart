import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/roadmap/data/roadmap_mapper.dart';

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
    });
  });
}
