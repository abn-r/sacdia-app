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
  String? clubName,
}) {
  return AuthorizationGrant(
    assignmentId: id,
    clubName: clubName,
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

Future<void> _openSheet(
  WidgetTester tester, {
  required List<AuthorizationGrant> assignments,
  String activeAssignmentId = 'aventureros',
}) async {
  final user = UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    authorization: AuthorizationSnapshot(
      activeAssignmentId: activeAssignmentId,
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
                activeAssignmentId: activeAssignmentId,
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
}

void main() {
  group('SectionSwitcherSheet', () {
    final cycleAssignments = [
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

    testWidgets(
      'should order club assignments by formation age cycle',
      (tester) async {
        await _openSheet(tester, assignments: cycleAssignments);

        final aventurerosY = _firstTextY(tester, 'Aventureros');
        final conquistadoresY = _firstTextY(tester, 'Conquistadores');
        final guiasY = _firstTextY(tester, 'Guías Mayores');

        expect(aventurerosY, lessThan(conquistadoresY));
        expect(conquistadoresY, lessThan(guiasY));
      },
    );

    testWidgets(
      'should show each club type name once when club name is absent',
      (tester) async {
        await _openSheet(tester, assignments: cycleAssignments);

        expect(find.text('Aventureros'), findsOneWidget);
        expect(find.text('Conquistadores'), findsOneWidget);
        expect(find.text('Guías Mayores'), findsOneWidget);
      },
    );

    testWidgets(
      'should use club name as title and club type as badge',
      (tester) async {
        final assignments = [
          _grant(
            id: 'conquistadores',
            clubName: 'ACV',
            clubTypeName: 'Conquistadores',
            roleName: 'director',
          ),
          _grant(
            id: 'guias',
            clubName: 'ACV',
            clubTypeName: 'Guías Mayores',
            roleName: 'member',
          ),
          _grant(
            id: 'aventureros',
            clubName: 'ACV',
            clubTypeName: 'Aventureros',
            roleName: 'director',
          ),
        ];

        await _openSheet(tester, assignments: assignments);

        expect(find.text('ACV'), findsNWidgets(3));
        expect(find.text('Aventureros'), findsOneWidget);
        expect(find.text('Conquistadores'), findsOneWidget);
        expect(find.text('Guías Mayores'), findsOneWidget);
      },
    );
  });
}
