import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';

Map<String, dynamic> _payload([Map<String, dynamic>? extra]) => {
      'user_id': 'user-1',
      'email': 'user@example.com',
      ...?extra,
    };

void main() {
  group('OnboardingMode.parse', () {
    test('parses the three server values', () {
      expect(OnboardingMode.parse('club'), OnboardingMode.club);
      expect(OnboardingMode.parse('club_exempt'), OnboardingMode.clubExempt);
      expect(OnboardingMode.parse('panel_only'), OnboardingMode.panelOnly);
    });

    test('missing or unknown values are club', () {
      for (final raw in <Object?>[null, '', 'other', 'CLUB-EXEMPT', 7, true]) {
        expect(OnboardingMode.parse(raw), OnboardingMode.club, reason: '$raw');
      }
    });
  });

  group('UserModel onboarding_mode', () {
    test('reads onboarding_mode from the /auth/me payload', () {
      final user = UserModel.fromCustomApi(
        _payload({'onboarding_mode': 'club_exempt'}),
      );
      expect(user.onboardingMode, OnboardingMode.clubExempt);
    });

    test('missing onboarding_mode (old backend) is club', () {
      expect(
        UserModel.fromCustomApi(_payload()).onboardingMode,
        OnboardingMode.club,
      );
    });

    test('unknown onboarding_mode is club', () {
      expect(
        UserModel.fromCustomApi(_payload({'onboarding_mode': 'future_mode'}))
            .onboardingMode,
        OnboardingMode.club,
      );
    });

    test('cache round-trip keeps the mode', () {
      for (final mode in OnboardingMode.values) {
        final user = UserModel.fromCustomApi(
          _payload({'onboarding_mode': mode.wireValue}),
        );
        expect(UserModel.fromJson(user.toJson()).onboardingMode, mode);
      }
    });

    test('a cache written before the field restores club', () {
      final json = UserModel.fromCustomApi(_payload()).toJson()
        ..remove('onboardingMode');
      expect(UserModel.fromJson(json).onboardingMode, OnboardingMode.club);
    });

    test('copyWith overrides and preserves the mode', () {
      final user = UserModel.fromCustomApi(
        _payload({'onboarding_mode': 'panel_only'}),
      );
      expect(
          user.copyWith(name: 'Ana').onboardingMode, OnboardingMode.panelOnly);
      expect(
        user.copyWith(onboardingMode: OnboardingMode.club).onboardingMode,
        OnboardingMode.club,
      );
    });

    test('is part of entity equality', () {
      final a = UserModel.fromCustomApi(_payload());
      final b = a.copyWith(onboardingMode: OnboardingMode.clubExempt);
      expect(a, isNot(equals(b)));
    });
  });
}
