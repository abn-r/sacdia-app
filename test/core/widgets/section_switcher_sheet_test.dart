import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/section_switcher_sheet.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

AuthorizationGrant _grant({
  required String id,
  required String clubTypeName,
  required String roleName,
}) {
  return AuthorizationGrant(
    assignmentId: id,
    clubTypeName: clubTypeName,
    roleName: roleName,
    clubId: 1,
    sectionId: 1,
    status: 'active',
  );
}

double _firstTextY(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsWidgets);

  return tester
      .widgetList<Text>(finder)
      .map((widget) => tester.getTopLeft(find.byWidget(widget)).dy)
      .reduce((a, b) => a < b ? a : b);
}

void main() {
  testWidgets(
    'orders club assignments by formation age cycle',
    (tester) async {
      final assignments = [
        _grant(
          id: 'conquistadores',
          clubTypeName: 'Conquistadores',
          roleName: 'director',
        ),
        _grant(
          id: 'guias',
          clubTypeName: 'Guías Mayores',
          roleName: 'member',
        ),
        _grant(
          id: 'aventureros',
          clubTypeName: 'Aventureros',
          roleName: 'director',
        ),
      ];

      final user = UserEntity(
        id: 'user-1',
        email: 'user@example.com',
        authorization: AuthorizationSnapshot(
          activeAssignmentId: 'aventureros',
          clubAssignments: assignments,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => showSectionSwitcher(
                    context: context,
                    ref: ref,
                    assignments: assignments,
                    activeAssignmentId: 'aventureros',
                    userGender: null,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final aventurerosY = _firstTextY(tester, 'Aventureros');
      final conquistadoresY = _firstTextY(tester, 'Conquistadores');
      final guiasY = _firstTextY(tester, 'Guías Mayores');

      expect(aventurerosY, lessThan(conquistadoresY));
      expect(conquistadoresY, lessThan(guiasY));
    },
  );
}
