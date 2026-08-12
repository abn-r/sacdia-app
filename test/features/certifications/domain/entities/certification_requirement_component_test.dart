import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement_component.dart';

void main() {
  group('certificationComponentTypeFromWire / wireValue', () {
    const cases = {
      'TEXT_RESPONSE': CertificationComponentType.textResponse,
      'FILE_EVIDENCE': CertificationComponentType.fileEvidence,
      'LINKED_HONOR': CertificationComponentType.linkedHonor,
      'LINKED_ACTIVITY': CertificationComponentType.linkedActivity,
      'ATTESTATION': CertificationComponentType.attestation,
      'AUTO_VALIDATION': CertificationComponentType.autoValidation,
    };

    for (final entry in cases.entries) {
      test('round-trips ${entry.key}', () {
        expect(certificationComponentTypeFromWire(entry.key), entry.value);
        expect(entry.value.wireValue, entry.key);
      });
    }

    test('unknown wire values fall back to unknown (never throw)', () {
      expect(
        certificationComponentTypeFromWire('SOMETHING_NEW'),
        CertificationComponentType.unknown,
      );
      expect(
        certificationComponentTypeFromWire(null),
        CertificationComponentType.unknown,
      );
    });
  });

  group('CertificationRequirementComponent.isComplete', () {
    CertificationRequirementComponent component({
      required CertificationComponentType type,
      CertificationComponentResponse? response,
    }) {
      return CertificationRequirementComponent(
        componentId: 1,
        type: type,
        label: 'Componente',
        required: true,
        response: response,
      );
    }

    test('AUTO_VALIDATION is always complete', () {
      expect(
        component(type: CertificationComponentType.autoValidation).isComplete,
        isTrue,
      );
    });

    test('TEXT_RESPONSE requires non-empty trimmed text', () {
      expect(
        component(type: CertificationComponentType.textResponse).isComplete,
        isFalse,
      );
      expect(
        component(
          type: CertificationComponentType.textResponse,
          response: const CertificationComponentResponse(textValue: '   '),
        ).isComplete,
        isFalse,
      );
      expect(
        component(
          type: CertificationComponentType.textResponse,
          response: const CertificationComponentResponse(textValue: 'Listo'),
        ).isComplete,
        isTrue,
      );
    });

    test('ATTESTATION requires attestationConfirmed == true', () {
      expect(
        component(type: CertificationComponentType.attestation).isComplete,
        isFalse,
      );
      expect(
        component(
          type: CertificationComponentType.attestation,
          response: const CertificationComponentResponse(
            attestationConfirmed: false,
          ),
        ).isComplete,
        isFalse,
      );
      expect(
        component(
          type: CertificationComponentType.attestation,
          response: const CertificationComponentResponse(
            attestationConfirmed: true,
          ),
        ).isComplete,
        isTrue,
      );
    });

    test('LINKED_HONOR requires a linkedUserHonorId', () {
      expect(
        component(type: CertificationComponentType.linkedHonor).isComplete,
        isFalse,
      );
      expect(
        component(
          type: CertificationComponentType.linkedHonor,
          response: const CertificationComponentResponse(
            linkedUserHonorId: 42,
          ),
        ).isComplete,
        isTrue,
      );
    });

    test('LINKED_ACTIVITY requires a linkedActivityId', () {
      expect(
        component(type: CertificationComponentType.linkedActivity).isComplete,
        isFalse,
      );
      expect(
        component(
          type: CertificationComponentType.linkedActivity,
          response: const CertificationComponentResponse(
            linkedActivityId: 7,
          ),
        ).isComplete,
        isTrue,
      );
    });

    test('FILE_EVIDENCE is complete once a response exists', () {
      expect(
        component(type: CertificationComponentType.fileEvidence).isComplete,
        isFalse,
      );
      expect(
        component(
          type: CertificationComponentType.fileEvidence,
          response: const CertificationComponentResponse(),
        ).isComplete,
        isTrue,
      );
    });

    test('unknown component type is never complete', () {
      expect(
        component(type: CertificationComponentType.unknown).isComplete,
        isFalse,
      );
    });
  });
}
