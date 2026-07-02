import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_module_detail.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_with_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/requirement_track.dart';
import 'package:sacdia_app/features/classes/domain/entities/track_eligibility.dart';
import 'package:sacdia_app/features/classes/domain/entities/track_progress.dart';

void main() {
  group('ClassWithProgress track progress', () {
    test('uses investiture progress excluding advanced requirements', () {
      final classData = ClassWithProgress(
        id: 1,
        name: 'Compañero',
        clubTypeId: 2,
        modules: const [
          ClassModuleDetail(
            id: 10,
            name: 'Módulo',
            classId: 1,
            requirements: [
              ClassRequirement(
                id: 100,
                name: 'Básico validado',
                moduleId: 10,
                status: RequirementStatus.validado,
                requirementTrack: RequirementTrack.basic,
              ),
              ClassRequirement(
                id: 101,
                name: 'Extra pendiente',
                moduleId: 10,
                status: RequirementStatus.pendiente,
                requirementTrack: RequirementTrack.extra,
              ),
              ClassRequirement(
                id: 102,
                name: 'Avanzado validado',
                moduleId: 10,
                status: RequirementStatus.validado,
                requirementTrack: RequirementTrack.advanced,
                requiredForInvestiture: false,
              ),
            ],
          ),
        ],
      );

      expect(classData.investitureProgressPercent, 50);
      expect(classData.completionPercent, 50);
      expect(classData.completionRatio, 0.5);
    });

    test('does not show empty disabled advanced progress as a section', () {
      final classData = ClassWithProgress(
        id: 1,
        name: 'Compañero',
        clubTypeId: 2,
        advancedProgress: const TrackProgress(
          percentage: 0,
          completed: 0,
          total: 0,
        ),
        advancedEligibility: const TrackEligibility(
          enabled: false,
          eligible: false,
        ),
      );

      expect(classData.hasAdvancedTrackData, isFalse);
    });

    test('shows advanced section when advanced progress has requirements', () {
      final classData = ClassWithProgress(
        id: 1,
        name: 'Compañero',
        clubTypeId: 2,
        advancedProgress: const TrackProgress(
          percentage: 25,
          completed: 1,
          total: 4,
        ),
      );

      expect(classData.hasAdvancedTrackData, isTrue);
    });
  });
}
