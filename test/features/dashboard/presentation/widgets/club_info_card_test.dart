import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/club_info_card.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _NullProfileNotifier extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

UserEntity _userForClubType(String clubTypeName) {
  const activeAssignmentId = 'assignment-1';

  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    authorization: AuthorizationSnapshot(
      activeAssignmentId: activeAssignmentId,
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: activeAssignmentId,
          clubTypeName: clubTypeName,
          roleName: 'director',
          clubId: 1,
          sectionId: 2,
          status: 'active',
        ),
      ],
    ),
  );
}

Future<void> _pumpClubInfoCard(
  WidgetTester tester, {
  required String clubTypeName,
}) async {
  final user = _userForClubType(clubTypeName);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        profileNotifierProvider.overrideWith(_NullProfileNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ClubInfoCard(
            clubName: 'ACV',
            clubType: clubTypeName,
            userRole: 'Director',
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('ClubInfoCard section badge', () {
    testWidgets(
      'uses the section switcher color for Aventureros',
      (tester) async {
        await _pumpClubInfoCard(tester, clubTypeName: 'Aventureros');

        final sectionLabel = tester.widget<Text>(find.text('Aventureros'));

        expect(sectionLabel.style?.color, const Color(0xFF1A6B9C));
      },
    );
  });
}
