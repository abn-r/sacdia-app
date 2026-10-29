import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/club_info_card.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

import '../../../coordinator/coordinator_test_harness.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(this._gender);

  final String? _gender;

  @override
  Future<UserDetail?> build() async => UserDetail(
        id: 'user-1',
        email: 'user@example.com',
        name: 'Ana',
        gender: _gender,
      );
}

UserEntity _userWithRole(String roleName) => UserEntity(
      id: 'user-1',
      email: 'user@example.com',
      authorization: AuthorizationSnapshot(
        activeAssignmentId: 'assignment-1',
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'assignment-1',
            clubTypeName: 'Conquistadores',
            roleName: roleName,
            clubId: 1,
            sectionId: 2,
            status: 'active',
          ),
        ],
      ),
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  required String roleName,
  required String? gender,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(_userWithRole(roleName)),
        ),
        profileNotifierProvider.overrideWith(
          () => _FakeProfileNotifier(gender),
        ),
      ],
      child: localized(
        (context) => MaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          home: const Scaffold(
            body: ClubInfoCard(clubName: 'ACV', clubType: 'Conquistadores'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('ClubInfoCard role chip follows the signed-in user gender', () {
    testWidgets('a woman secretary sees "Secretaria"', (tester) async {
      await _pumpCard(tester, roleName: 'secretary', gender: 'F');

      expect(find.text('Secretaria'), findsOneWidget);
      expect(find.text('Secretario'), findsNothing);
    });

    testWidgets('a man secretary-treasurer sees the masculine label',
        (tester) async {
      await _pumpCard(tester, roleName: 'secretary-treasurer', gender: 'M');

      expect(find.text('Secretario-Tesorero'), findsOneWidget);
    });

    testWidgets('a woman secretary-treasurer sees the feminine label',
        (tester) async {
      await _pumpCard(tester, roleName: 'secretary-treasurer', gender: 'F');

      expect(find.text('Secretaria-Tesorera'), findsOneWidget);
    });

    testWidgets('unknown gender keeps the masculine label', (tester) async {
      await _pumpCard(tester, roleName: 'secretary', gender: null);

      expect(find.text('Secretario'), findsOneWidget);
    });
  });
}
