import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/members_view.dart';

import '../../members_test_support.dart';
import '../../role_candidates_test_support.dart';

UserEntity _user({
  required List<String> capabilities,
  int? clubTypeId = 1,
  String? clubTypeName = 'Aventureros',
}) =>
    UserEntity(
      id: 'director-1',
      email: 'director@example.com',
      name: 'Laura',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(
        effectivePermissions: const [],
        capabilities: capabilities,
        activeAssignmentId: 'asg-dir',
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'asg-dir',
            roleName: 'director',
            clubId: 1,
            sectionId: 163,
            clubTypeId: clubTypeId,
            clubTypeName: clubTypeName,
            status: 'active',
          ),
        ],
      ),
    );

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this.user);
  final UserEntity user;

  @override
  Future<UserEntity?> build() async => user;
}

class _EmptyContinuations extends AnnualContinuationsNotifier {
  @override
  Future<AnnualContinuationsState> build() async =>
      const AnnualContinuationsState(items: []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;

  setUp(() {
    repo = FakeMembersRepository()
      ..roleCandidatesResults = [
        Right(candidatesPage([candidate()])),
      ];
  });

  Future<void> open(WidgetTester tester, UserEntity user) async {
    await pumpMembersApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuth(user)),
        membersRepositoryProvider.overrideWithValue(repo),
        annualContinuationsNotifierProvider
            .overrideWith(_EmptyContinuations.new),
      ],
      home: const MembersView(),
    );
    await tester.pumpAndSettle();
  }

  const entry = 'Agregar directivo';

  testWidgets(
      'capability + Aventureros section: the entry is there and opens '
      'the sheet for the section', (tester) async {
    await open(tester, _user(capabilities: ['club_roles.assign_section']));

    expect(find.text(entry), findsOneWidget);

    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();

    // Sheet header + the entry button behind it.
    expect(find.text('Laura Méndez'), findsOneWidget);
    expect(repo.roleCandidateCalls.single.clubId, 1);
    expect(repo.roleCandidateCalls.single.sectionId, 163);
  });

  testWidgets('capability + Conquistadores section: the entry is there',
      (tester) async {
    await open(
      tester,
      _user(
        capabilities: ['club_roles.assign_section'],
        clubTypeId: 2,
        clubTypeName: 'Conquistadores',
      ),
    );

    expect(find.text(entry), findsOneWidget);
  });

  testWidgets('without the capability there is no entry, whatever the role',
      (tester) async {
    await open(tester, _user(capabilities: const []));

    expect(find.text(entry), findsNothing);
  });

  testWidgets('the Guías Mayores section never offers it (by type id)',
      (tester) async {
    await open(
      tester,
      _user(
        capabilities: ['club_roles.assign_section'],
        clubTypeId: 3,
        clubTypeName: 'Guías Mayores',
      ),
    );

    expect(find.text(entry), findsNothing);
  });

  testWidgets('the Guías Mayores section never offers it (by name only)',
      (tester) async {
    await open(
      tester,
      _user(
        capabilities: ['club_roles.assign_section'],
        clubTypeId: null,
        clubTypeName: 'Guías Mayores',
      ),
    );

    expect(find.text(entry), findsNothing);
  });
}
