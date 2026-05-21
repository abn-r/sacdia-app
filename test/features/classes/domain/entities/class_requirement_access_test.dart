import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/domain/entities/requirement_evidence.dart';

void main() {
  group('ClassRequirement class-expiration access', () {
    test('blocks upload and submit when the class is expired', () {
      final requirement = ClassRequirement(
        id: 1,
        name: 'Evidence',
        moduleId: 10,
        status: RequirementStatus.pendiente,
        files: [
          RequirementEvidence(
            id: 'file-1',
            url: 'https://example.test/file.jpg',
            fileName: 'file.jpg',
            type: EvidenceFileType.image,
            uploadedByName: 'Ada',
            uploadedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      expect(requirement.canUploadForClass(isClassExpired: true), isFalse);
      expect(requirement.canSubmitForClass(isClassExpired: true), isFalse);
    });

    test('allows upload and submit for active editable requirements', () {
      final requirement = ClassRequirement(
        id: 1,
        name: 'Evidence',
        moduleId: 10,
        status: RequirementStatus.pendiente,
        files: [
          RequirementEvidence(
            id: 'file-1',
            url: 'https://example.test/file.jpg',
            fileName: 'file.jpg',
            type: EvidenceFileType.image,
            uploadedByName: 'Ada',
            uploadedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      expect(requirement.canUploadForClass(isClassExpired: false), isTrue);
      expect(requirement.canSubmitForClass(isClassExpired: false), isTrue);
    });
  });
}
