import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_work_navigation.dart';

void main() {
  group('honorWorkDestinationPath', () {
    UserHonor honor({
      HonorCompletionMode completionMode = HonorCompletionMode.undecided,
      String validationStatus = 'IN_PROGRESS',
      String? honorName = 'Perros',
    }) {
      return UserHonor(
        id: 33,
        honorId: 10,
        userId: 'user-1',
        validationStatus: validationStatus,
        completionMode: completionMode,
        honorName: honorName,
        date: DateTime(2026, 6, 16),
      );
    }

    test('should open mode selector when honor is still undecided', () {
      expect(honorWorkDestinationPath(honor()), '/honor/10');
    });

    test('should open requirements directly for in-app honors', () {
      expect(
        honorWorkDestinationPath(
          honor(completionMode: HonorCompletionMode.inApp),
        ),
        '/honor/10/requirements/33?name=Perros',
      );
    });

    test('should prefer explicit honorName for requirements', () {
      expect(
        honorWorkDestinationPath(
          honor(completionMode: HonorCompletionMode.inApp, honorName: null),
          honorName: 'Aeromodelismo',
        ),
        '/honor/10/requirements/33?name=Aeromodelismo',
      );
    });

    test('should open external evidence directly for external honors', () {
      expect(
        honorWorkDestinationPath(
          honor(completionMode: HonorCompletionMode.external),
        ),
        '/honor/10/evidence/33',
      );
    });

    test('should open detail history for approved honors', () {
      expect(
        honorWorkDestinationPath(
          honor(
            completionMode: HonorCompletionMode.external,
            validationStatus: 'APPROVED',
          ),
        ),
        '/honor/10',
      );
    });

    test('shouldResumeHonorWork is true only for active in-app or external',
        () {
      expect(shouldResumeHonorWork(honor()), isFalse);
      expect(
        shouldResumeHonorWork(honor(completionMode: HonorCompletionMode.inApp)),
        isTrue,
      );
      expect(
        shouldResumeHonorWork(
          honor(completionMode: HonorCompletionMode.external),
        ),
        isTrue,
      );
      expect(
        shouldResumeHonorWork(
          honor(
            completionMode: HonorCompletionMode.inApp,
            validationStatus: 'APPROVED',
          ),
        ),
        isFalse,
      );
    });
  });
}
