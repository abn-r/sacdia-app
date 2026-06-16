import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/profile/presentation/utils/profile_honor_navigation.dart';

void main() {
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

  test('opens mode selector when profile honor is still undecided', () {
    expect(profileHonorDestinationPath(honor()), '/honor/10');
  });

  test('opens requirements directly for in-app honors', () {
    expect(
      profileHonorDestinationPath(
        honor(completionMode: HonorCompletionMode.inApp),
      ),
      '/honor/10/requirements/33?name=Perros',
    );
  });

  test('opens external evidence directly for external honors', () {
    expect(
      profileHonorDestinationPath(
        honor(completionMode: HonorCompletionMode.external),
      ),
      '/honor/10/evidence/33',
    );
  });

  test('opens detail history for approved honors', () {
    expect(
      profileHonorDestinationPath(
        honor(
          completionMode: HonorCompletionMode.external,
          validationStatus: 'APPROVED',
        ),
      ),
      '/honor/10',
    );
  });
}
