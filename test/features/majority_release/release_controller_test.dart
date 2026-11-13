import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_status.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/features/majority_release/presentation/majority_release_error_messages.dart';
import 'package:sacdia_app/features/majority_release/presentation/providers/majority_release_providers.dart';

import '../../support/riverpod_test_support.dart';
import '../family/family_test_harness.dart' show initLocalization;
import 'majority_release_test_support.dart';

ServerFailure _fail(String code, {int status = 409}) =>
    ServerFailure(message: 'x', code: status, errorCode: code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeLegalRepository legal;
  late FakeMajorityReleaseRepository release;
  late RecordingAuth auth;
  late ProviderContainer container;

  setUp(() {
    legal = FakeLegalRepository();
    release = FakeMajorityReleaseRepository();
    auth = RecordingAuth(releasedUser(needsEmail: true));
    container = createTestContainer(
      overrides: [
        legalRepositoryProvider.overrideWithValue(legal),
        majorityReleaseRepositoryProvider.overrideWithValue(release),
        authNotifierProvider.overrideWith(() => auth),
      ],
    );
  });

  ReleaseController controller() =>
      container.read(releaseControllerProvider.notifier);

  group('accept (called without listening: autoDispose + keepAliveDuring)', () {
    test('sends the versions the person saw and re-reads /auth/me', () async {
      await container.read(authNotifierProvider.future);
      final ok = await controller().accept(legalStatusFixture);

      expect(ok, isTrue);
      expect(legal.accepts, [(terms: '2.0.0-family', privacy: '2.0.0-family')]);
      expect(auth.refreshes, 1);
    });

    test('LEGAL_VERSION_MISMATCH asks for the new versions', () async {
      await container.read(authNotifierProvider.future);
      legal.acceptResult = Left(_fail(legalVersionMismatchCode, status: 400));
      // Mantiene vivo el estado para leerlo después.
      final sub = container.listen(releaseControllerProvider, (_, __) {});
      addTearDown(sub.close);

      final ok = await controller().accept(legalStatusFixture);

      expect(ok, isFalse);
      expect(container.read(releaseControllerProvider).acceptError,
          legalVersionChangedKey);
      expect(auth.refreshes, 0);
    });

    test('a generic failure shows the generic error', () async {
      await container.read(authNotifierProvider.future);
      legal.acceptResult = const Left(ServerFailure(message: 'boom'));
      final sub = container.listen(releaseControllerProvider, (_, __) {});
      addTearDown(sub.close);

      expect(await controller().accept(legalStatusFixture), isFalse);
      expect(container.read(releaseControllerProvider).acceptError,
          legalAcceptErrorKey);
      expect(container.read(releaseControllerProvider).accepting, isFalse);
    });

    test('FAMILY_RELEASE_NOT_PENDING resyncs instead of erroring', () async {
      await container.read(authNotifierProvider.future);
      legal.acceptResult = Left(_fail('FAMILY_RELEASE_NOT_PENDING'));
      final sub = container.listen(releaseControllerProvider, (_, __) {});
      addTearDown(sub.close);

      expect(await controller().accept(legalStatusFixture), isFalse);
      expect(container.read(releaseControllerProvider).acceptError, isNull);
      expect(auth.refreshes, 1);
    });

    test('without versions nothing is sent', () async {
      await container.read(authNotifierProvider.future);
      final sub = container.listen(releaseControllerProvider, (_, __) {});
      addTearDown(sub.close);

      final ok = await controller()
          .accept(const LegalStatus(requiresAcceptance: true, documents: []));

      expect(ok, isFalse);
      expect(legal.accepts, isEmpty);
    });
  });

  group('addEmail', () {
    test('success marks the verification hint and re-reads /auth/me', () async {
      await container.read(authNotifierProvider.future);
      final sub = container.listen(releaseControllerProvider, (_, __) {});
      addTearDown(sub.close);

      expect(await controller().addEmail('ana@example.com'), isTrue);

      expect(release.emails, ['ana@example.com']);
      expect(container.read(releaseControllerProvider).emailAdded, isTrue);
      expect(container.read(releaseControllerProvider).emailError, isNull);
      expect(auth.refreshes, 1);
    });

    test('FAMILY_RELEASE_EMAIL_UNAVAILABLE becomes an inline translated error',
        () async {
      await container.read(authNotifierProvider.future);
      release.emailResult = Left(_fail('FAMILY_RELEASE_EMAIL_UNAVAILABLE'));
      final sub = container.listen(releaseControllerProvider, (_, __) {});
      addTearDown(sub.close);

      expect(await controller().addEmail('taken@example.com'), isFalse);

      final state = container.read(releaseControllerProvider);
      // Sin EasyLocalization montado `tr()` devuelve la llave: se comprueba que
      // sea la del código, no un texto del servidor.
      expect(state.emailError, 'errors.family_release_email_unavailable');
      expect(state.emailAdded, isFalse);
      expect(state.addingEmail, isFalse);
      expect(auth.refreshes, 0);
    });

    test('FAMILY_RELEASE_EMAIL_ALREADY_SET resyncs (stale needs_email)',
        () async {
      await container.read(authNotifierProvider.future);
      release.emailResult = Left(_fail('FAMILY_RELEASE_EMAIL_ALREADY_SET'));
      final sub = container.listen(releaseControllerProvider, (_, __) {});
      addTearDown(sub.close);

      expect(await controller().addEmail('a@b.co'), isFalse);
      expect(container.read(releaseControllerProvider).emailError, isNull);
      expect(auth.refreshes, 1);
    });

    test('a network failure shows the connection message', () async {
      await container.read(authNotifierProvider.future);
      release.emailResult = const Left(NetworkFailure(message: 'offline'));
      final sub = container.listen(releaseControllerProvider, (_, __) {});
      addTearDown(sub.close);

      await controller().addEmail('a@b.co');
      expect(container.read(releaseControllerProvider).emailError, isNotNull);
    });
  });

  group('error mapping by code', () {
    test('every Phase 4 code maps to its own errors.* key', () {
      expect(majorityReleaseErrorCodes, hasLength(5));
      for (final code in majorityReleaseErrorCodes) {
        expect(
          majorityReleaseErrorMessage(_fail(code)),
          'errors.${code.toLowerCase()}',
          reason: code,
        );
      }
    });

    test('family codes and lockout fall through to the family messages', () {
      expect(
        majorityReleaseErrorMessage(
            _fail('GUARDIANSHIP_LINK_CODE_INVALID', status: 400)),
        'errors.guardianship_link_code_invalid',
      );
      expect(
        majorityReleaseErrorMessage(
            _fail('GUARDIANSHIP_LINK_CODE_LOCKED', status: 429)),
        'errors.guardianship_link_code_locked',
      );
    });

    test('stale-state detection', () {
      expect(isStaleReleaseState(_fail('FAMILY_RELEASE_NOT_PENDING')), isTrue);
      expect(isStaleReleaseState(_fail('FAMILY_RELEASE_EMAIL_ALREADY_SET')),
          isTrue);
      expect(isStaleReleaseState(_fail('FAMILY_RELEASE_EMAIL_UNAVAILABLE')),
          isFalse);
    });
  });

  group('adult claim controller', () {
    test('success has no session and exposes success', () async {
      final sub = container.listen(adultClaimControllerProvider, (_, __) {});
      addTearDown(sub.close);
      final ok = await container
          .read(adultClaimControllerProvider.notifier)
          .redeem(code: 'AB12', email: 'a@b.co', password: 'Passw0rd!xyz');

      expect(ok, isTrue);
      expect(release.redeems.single.email, 'a@b.co');
      expect(container.read(adultClaimControllerProvider).success, isTrue);
    });

    test('an invalid code shows the generic family error', () async {
      release.redeemResult =
          Left(_fail('GUARDIANSHIP_LINK_CODE_INVALID', status: 400));
      final sub = container.listen(adultClaimControllerProvider, (_, __) {});
      addTearDown(sub.close);

      final ok = await container
          .read(adultClaimControllerProvider.notifier)
          .redeem(code: 'X', email: 'a@b.co', password: 'Passw0rd!xyz');

      expect(ok, isFalse);
      final state = container.read(adultClaimControllerProvider);
      expect(state.error, isNotNull);
      expect(state.success, isFalse);
      expect(state.submitting, isFalse);
    });

    test('lockout (429) is mapped, not raw', () async {
      release.redeemResult =
          Left(_fail('GUARDIANSHIP_LINK_CODE_LOCKED', status: 429));
      final sub = container.listen(adultClaimControllerProvider, (_, __) {});
      addTearDown(sub.close);

      await container
          .read(adultClaimControllerProvider.notifier)
          .redeem(code: 'X', email: 'a@b.co', password: 'Passw0rd!xyz');
      final lockout = container.read(adultClaimControllerProvider).error;

      release.redeemResult =
          Left(_fail('GUARDIANSHIP_LINK_CODE_INVALID', status: 400));
      await container
          .read(adultClaimControllerProvider.notifier)
          .redeem(code: 'X', email: 'a@b.co', password: 'Passw0rd!xyz');
      // The lockout message differs from the uniform invalid-code message.
      expect(
          lockout, isNot(container.read(adultClaimControllerProvider).error));
    });

    test('email unavailable and not released map to their own text', () async {
      for (final code in [
        'FAMILY_ADULT_CLAIM_EMAIL_UNAVAILABLE',
        'FAMILY_ADULT_CLAIM_NOT_RELEASED',
      ]) {
        release.redeemResult = Left(_fail(code));
        final sub = container.listen(adultClaimControllerProvider, (_, __) {});
        await container
            .read(adultClaimControllerProvider.notifier)
            .redeem(code: 'X', email: 'a@b.co', password: 'Passw0rd!xyz');
        expect(container.read(adultClaimControllerProvider).error,
            majorityReleaseErrorMessage(_fail(code)));
        sub.close();
      }
    });
  });
}
