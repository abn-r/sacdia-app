import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import 'auth_notifier_test_support.dart';

/// Repositorio que arranca con una sesión ya guardada para [user].
class _SessionRepo extends FakeAuthRepository {
  _SessionRepo(this.user);

  UserEntity user;

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async => Right(user);
}

void main() {
  group('pushReadyFor', () {
    test('waits for post-registration and the legal documents', () {
      expect(pushReadyFor(const UserEntity(id: 'u')), isFalse);
      expect(
        pushReadyFor(const UserEntity(
          id: 'u',
          postRegisterComplete: true,
          legalAcceptancePending: true,
        )),
        isFalse,
      );
      expect(
        pushReadyFor(const UserEntity(id: 'u', postRegisterComplete: true)),
        isTrue,
      );
    });

    for (final mode in OnboardingMode.values) {
      for (final complete in [true, false]) {
        for (final legalPending in [true, false]) {
          // Una cuenta de solo panel nunca completa el post-registro: está
          // lista aunque la bandera siga en falso.
          final needsRegistration =
              mode != OnboardingMode.panelOnly && !complete;
          final expected = !needsRegistration && !legalPending;
          test(
              '${mode.name} complete=$complete legalPending=$legalPending '
              '-> $expected', () {
            expect(
              pushReadyFor(UserEntity(
                id: 'u',
                onboardingMode: mode,
                postRegisterComplete: complete,
                legalAcceptancePending: legalPending,
              )),
              expected,
            );
          });
        }
      }
    }

    test('a panel-only account with legal documents pending is not ready', () {
      expect(
        pushReadyFor(const UserEntity(
          id: 'u',
          onboardingMode: OnboardingMode.panelOnly,
          legalAcceptancePending: true,
        )),
        isFalse,
      );
    });

    test('an account without birth date is never ready, even panel-only', () {
      for (final mode in OnboardingMode.values) {
        expect(
          pushReadyFor(UserEntity(
            id: 'u',
            onboardingMode: mode,
            postRegisterComplete: true,
            principal: const PrincipalInfo(kind: PrincipalKind.ageUnknownUser),
          )),
          isFalse,
          reason: mode.name,
        );
      }
    });

    test('a linked device is always ready', () {
      expect(
        pushReadyFor(const UserEntity(
          id: 'kid',
          principal: PrincipalInfo(kind: PrincipalKind.linkedDevice),
        )),
        isTrue,
      );
    });
  });

  group('AuthNotifier', () {
    late ProviderContainer container;

    Future<void> boot(UserEntity user) async {
      container = await buildAuthContainer(repo: _SessionRepo(user));
      await container.read(authNotifierProvider.future);
    }

    FakePushNotificationService push() =>
        container.read(pushNotificationServiceProvider)
            as FakePushNotificationService;

    test('does not ask for notifications while post-registration is open',
        () async {
      await boot(const UserEntity(id: 'new-user'));
      expect(push().initializeCalls, 0);
    });

    test('asks once post-registration is completed', () async {
      await boot(const UserEntity(id: 'new-user'));

      container
          .read(authNotifierProvider.notifier)
          .markPostRegisterComplete(forUserId: 'new-user');

      expect(push().initializeCalls, 1);
    });

    test('waits for the legal documents, then asks', () async {
      await boot(const UserEntity(
        id: 'u',
        postRegisterComplete: true,
        legalAcceptancePending: true,
      ));
      expect(push().initializeCalls, 0);

      container.read(authNotifierProvider.notifier).markLegalAccepted();

      expect(push().initializeCalls, 1);
    });

    test('a panel-only account asks on startup although it never completes',
        () async {
      await boot(const UserEntity(
        id: 'panel',
        onboardingMode: OnboardingMode.panelOnly,
      ));
      expect(push().initializeCalls, 1);
    });

    test('a club-exempt account waits for post-registration', () async {
      await boot(const UserEntity(
        id: 'exempt',
        onboardingMode: OnboardingMode.clubExempt,
      ));
      expect(push().initializeCalls, 0);
    });

    test('a registered account asks on startup as before', () async {
      await boot(const UserEntity(id: 'u', postRegisterComplete: true));
      expect(push().initializeCalls, 1);
    });
  });
}
