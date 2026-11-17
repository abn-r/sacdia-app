import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/insurance/presentation/utils/insurance_formatting.dart';

InsurancePerson _p(InsurancePersonStatus status) =>
    InsurancePerson(userId: 'u', name: 'N', status: status);

void main() {
  group('status to the shared kinds', () {
    test('maps each person status onto the status-progress grammar', () {
      expect(insuranceStatusKind(InsurancePersonStatus.covered),
          SacStatusKind.validated);
      expect(insuranceStatusKind(InsurancePersonStatus.inOrder),
          SacStatusKind.review);
      expect(insuranceStatusKind(InsurancePersonStatus.inReview),
          SacStatusKind.review);
      expect(insuranceStatusKind(InsurancePersonStatus.proofRejected),
          SacStatusKind.rejected);
      expect(insuranceStatusKind(InsurancePersonStatus.uninsured),
          SacStatusKind.pending);
    });
  });

  group('filters', () {
    test('each chip matches its group', () {
      expect(
        insuranceFilterMatches(
          InsuranceFilter.uninsured,
          _p(InsurancePersonStatus.uninsured),
        ),
        isTrue,
      );
      expect(
        insuranceFilterMatches(
          InsuranceFilter.uninsured,
          _p(InsurancePersonStatus.covered),
        ),
        isFalse,
      );
      for (final s in [
        InsurancePersonStatus.inOrder,
        InsurancePersonStatus.inReview,
        InsurancePersonStatus.proofRejected,
      ]) {
        expect(
            insuranceFilterMatches(InsuranceFilter.inProcess, _p(s)), isTrue);
        expect(insuranceFilterMatches(InsuranceFilter.covered, _p(s)), isFalse);
      }
      expect(
        insuranceFilterMatches(
          InsuranceFilter.covered,
          _p(InsurancePersonStatus.covered),
        ),
        isTrue,
      );
      for (final s in InsurancePersonStatus.values) {
        expect(insuranceFilterMatches(InsuranceFilter.all, _p(s)), isTrue);
      }
    });
  });

  test('normalize drops case and accents for the search box', () {
    expect(insuranceNormalize('Sofía NAVARRO'), 'sofia navarro');
    expect(insuranceNormalize('Joaquín Peña'), 'joaquin pena');
  });

  test('place joins section and club, skipping what is missing', () {
    expect(insurancePlace('Guías Mayores', 'Club Orión'),
        'Guías Mayores · Club Orión');
    expect(insurancePlace('Guías Mayores', null), 'Guías Mayores');
    expect(insurancePlace(null, 'Club Orión'), 'Club Orión');
    expect(insurancePlace(null, ''), isNull);
  });
}
