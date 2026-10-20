import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/create_minor_view.dart';
import 'package:sacdia_app/features/members/presentation/views/members_view.dart';

import '../../members_test_support.dart';

UserEntity _director({
  required List<String> permissions,
  FamilyFeatures? features,
}) =>
    UserEntity(
      id: 'director-1',
      email: 'director@example.com',
      name: 'Laura',
      postRegisterComplete: true,
      familyFeatures: features,
      authorization: AuthorizationSnapshot(
        effectivePermissions: permissions,
        activeAssignmentId: 'asg-dir',
        clubAssignments: const [
          AuthorizationGrant(
            assignmentId: 'asg-dir',
            roleName: 'director',
            clubId: 1,
            sectionId: 12,
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

  setUp(() => repo = FakeMembersRepository());

  Future<void> open(WidgetTester tester, UserEntity user) async {
    await pumpMembersApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuth(user)),
        membersRepositoryProvider.overrideWithValue(repo),
        annualContinuationsNotifierProvider
            .overrideWith(_EmptyContinuations.new),
        currentLegalDocumentsProvider.overrideWith(
          (ref) async => const [
            LegalDocument(
              documentType: LegalDocumentTypes.terms,
              version: '2.0.0-family',
              url: 'https://example.com/terms',
            ),
            LegalDocument(
              documentType: LegalDocumentTypes.privacy,
              version: '2.0.0-family',
              url: 'https://example.com/privacy',
            ),
          ],
        ),
      ],
      home: const MembersView(),
    );
    await tester.pumpAndSettle();
  }

  Finder entry() => find.byTooltip('Registrar un menor');

  testWidgets('no dependents:create: there is no entry', (tester) async {
    await open(
      tester,
      _director(
        permissions: ['club_members:approve'],
        features: const FamilyFeatures(directorCreateMinor: true),
      ),
    );

    expect(entry(), findsNothing);
  });

  testWidgets('flag off: there is no entry even with the permission',
      (tester) async {
    await open(
      tester,
      _director(
        permissions: ['club_members:approve', 'dependents:create'],
        features: const FamilyFeatures(),
      ),
    );

    expect(entry(), findsNothing);
  });

  testWidgets('permission and flag: the entry opens the form for the section',
      (tester) async {
    await open(
      tester,
      _director(
        permissions: ['club_members:approve', 'dependents:create'],
        features: const FamilyFeatures(directorCreateMinor: true),
      ),
    );

    expect(entry(), findsOneWidget);
    await tester.tap(entry());
    await tester.pumpAndSettle();

    final view = tester.widget<CreateMinorView>(find.byType(CreateMinorView));
    expect(view.clubSectionId, 12);
  });
}
