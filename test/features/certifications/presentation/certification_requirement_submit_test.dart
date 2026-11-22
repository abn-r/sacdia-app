import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certification_requirement_providers.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';

import '../../../support/l10n_test_support.dart';
import '../../../support/riverpod_test_support.dart';
import 'certification_test_support.dart';

void main() {
  setUpAll(loadSpanishTranslations);

  const query = CertificationRequirementQuery(
    certificationId: 2,
    sectionId: 22,
    enrollmentId: 7,
  );

  Future<(FakeCertificationsRepository, CertificationRequirementNotifier)>
      setUp_({int? lockVersion}) async {
    final repository = FakeCertificationsRepository()
      ..requirement = sampleRequirement(lockVersion: lockVersion);
    final container = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(FakeCertificationAuth.new),
        certificationsRepositoryProvider.overrideWithValue(repository),
        certificationDraftLocalDataSourceProvider
            .overrideWithValue(FakeDraftSource()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
        certificationRequirementNotifierProvider(query), (_, __) {});
    await container.read(authNotifierProvider.future);
    // Let the notifier's first load land.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return (
      repository,
      container.read(certificationRequirementNotifierProvider(query).notifier),
    );
  }

  test('submit sends the lock_version the server returned', () async {
    final (repository, notifier) = await setUp_(lockVersion: 3);

    final ok = await notifier.submit();

    expect(ok, isTrue);
    expect(repository.lastLockVersion, 3);
  });

  test('an unexpected error releases the button and keeps a message', () async {
    final (repository, notifier) = await setUp_(lockVersion: 1);
    repository.submitError = Exception('socket closed');

    final ok = await notifier.submit();

    expect(ok, isFalse);
    final state = notifier.state;
    expect(state.isSubmitting, isFalse);
    expect(state.errorMessage, isNotNull);
  });
}
