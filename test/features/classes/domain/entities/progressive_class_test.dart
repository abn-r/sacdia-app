import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';

void main() {
  ProgressiveClass buildClass({
    required String name,
    int clubTypeId = 2,
    String? assetCode,
    String? investitureStatus,
  }) {
    return ProgressiveClass(
      id: 1,
      name: name,
      clubTypeId: clubTypeId,
      assetCode: assetCode,
      investitureStatus: investitureStatus,
    );
  }

  group('ProgressiveClass.isInvestedMasterGuide', () {
    test('should be true when Guía Mayor is invested', () {
      final progressiveClass = buildClass(
        name: 'Guía Mayor',
        clubTypeId: ProgressiveClass.masterGuidesClubTypeId,
        investitureStatus: 'INVESTIDO',
      );

      expect(progressiveClass.isInvestedMasterGuide, isTrue);
    });

    test('should be true when a GM-track class is invested via asset code', () {
      final progressiveClass = buildClass(
        name: 'Máster',
        clubTypeId: 0,
        assetCode: 'GM-02',
        investitureStatus: 'investido',
      );

      expect(progressiveClass.isInvestedMasterGuide, isTrue);
    });

    test('should be false when Guía Mayor is not invested yet', () {
      final progressiveClass = buildClass(
        name: 'Guía Mayor',
        clubTypeId: ProgressiveClass.masterGuidesClubTypeId,
        investitureStatus: 'PENDIENTE',
      );

      expect(progressiveClass.isInvestedMasterGuide, isFalse);
    });

    test('should be false for the Pathfinder class named Guía', () {
      final progressiveClass = buildClass(
        name: 'Guía',
        clubTypeId: 2,
        assetCode: 'CQ-06',
        investitureStatus: 'INVESTIDO',
      );

      expect(progressiveClass.isMasterGuidesTrack, isFalse);
      expect(progressiveClass.isInvestedMasterGuide, isFalse);
    });
  });
}
