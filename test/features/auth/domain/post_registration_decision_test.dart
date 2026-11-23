import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';

const _clubGrant = AuthorizationGrant(
  assignmentId: 'a1',
  roleName: 'member',
  clubId: 1,
  sectionId: 4,
  status: 'active',
);

UserEntity _user({
  OnboardingMode onboardingMode = OnboardingMode.club,
  bool postRegisterComplete = false,
  AccountMode? serverMode,
  FamilySummary? family,
  ActingForInfo? actingFor,
  List<AuthorizationGrant> clubAssignments = const [],
  AuthorizationSnapshot? authorization,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      onboardingMode: onboardingMode,
      postRegisterComplete: postRegisterComplete,
      serverMode: serverMode,
      family: family,
      actingFor: actingFor,
      authorization: authorization ??
          AuthorizationSnapshot(clubAssignments: clubAssignments),
    );

void main() {
  group('userNeedsPostRegistration (server decides)', () {
    for (final mode in OnboardingMode.values) {
      for (final complete in [true, false]) {
        final expected = mode != OnboardingMode.panelOnly && !complete;
        test(
          '$mode, complete=$complete -> needs=$expected',
          () {
            expect(
              userNeedsPostRegistration(
                _user(onboardingMode: mode, postRegisterComplete: complete),
              ),
              expected,
            );
          },
        );
      }

      test('$mode with profile_incomplete always needs it', () {
        for (final complete in [true, false]) {
          expect(
            userNeedsPostRegistration(
              _user(
                onboardingMode: mode,
                postRegisterComplete: complete,
                serverMode: AccountMode.profileIncomplete,
              ),
            ),
            isTrue,
            reason: '$mode complete=$complete',
          );
        }
      });
    }

    test('a club-exempt account without a club is not exempt locally', () {
      // Sin exención por rol ni por clubes: solo cuenta lo que dice el servidor.
      expect(
        userNeedsPostRegistration(
          _user(onboardingMode: OnboardingMode.clubExempt),
        ),
        isTrue,
      );
      expect(
        userNeedsPostRegistration(
          _user(
            onboardingMode: OnboardingMode.clubExempt,
            postRegisterComplete: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('isGuardianAccount', () {
    test('is true for a guardian flag or any dependent', () {
      expect(
        isGuardianAccount(
          _user(
            family: const FamilySummary(isGuardian: true, dependentsCount: 0),
          ),
        ),
        isTrue,
      );
      expect(
        isGuardianAccount(
          _user(
            family: const FamilySummary(isGuardian: false, dependentsCount: 2),
          ),
        ),
        isTrue,
      );
    });

    test('is false without family data, without dependents or when null', () {
      expect(isGuardianAccount(null), isFalse);
      expect(isGuardianAccount(_user()), isFalse);
      expect(
        isGuardianAccount(
          _user(
            family: const FamilySummary(isGuardian: false, dependentsCount: 0),
          ),
        ),
        isFalse,
      );
    });

    test('is false while acting for a dependent', () {
      expect(
        isGuardianAccount(
          _user(
            family: const FamilySummary(isGuardian: true, dependentsCount: 1),
            actingFor: const ActingForInfo(
              actorUserId: 'u1',
              dependentUserId: 'ana',
            ),
          ),
        ),
        isFalse,
      );
    });

    test('ignores clubs and the completion flag', () {
      final guardianWithClub = _user(
        family: const FamilySummary(isGuardian: true, dependentsCount: 1),
        clubAssignments: const [_clubGrant],
      );
      expect(isGuardianAccount(guardianWithClub), isTrue);
      // isGuardianWithoutClub sí mira clubes y reutiliza isGuardianAccount.
      expect(isGuardianWithoutClub(guardianWithClub), isFalse);
    });

    test('isGuardianWithoutClub keeps its completed-without-club fallback', () {
      final completed = _user(postRegisterComplete: true);
      expect(isGuardianAccount(completed), isFalse);
      expect(isGuardianWithoutClub(completed), isTrue);
      expect(
        isGuardianWithoutClub(
          _user(
            family: const FamilySummary(isGuardian: true, dependentsCount: 1),
          ),
        ),
        isTrue,
      );
    });
  });
}
