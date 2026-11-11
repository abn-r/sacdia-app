import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/members_view.dart';
import 'package:sacdia_app/features/members/presentation/widgets/members_list_skeleton.dart';

import '../../members_test_support.dart';

const _user = UserEntity(
  id: 'user-1',
  email: 'user@example.com',
  name: 'Laura',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    effectivePermissions: [],
    activeAssignmentId: 'asg-1',
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'asg-1',
        roleName: 'counselor',
        clubId: 1,
        sectionId: 12,
        status: 'active',
      ),
    ],
  ),
);

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  late FakeMembersRepository repo;

  setUp(() {
    repo = FakeMembersRepository()
      ..members = const [
        ClubMember(userId: 'ana', name: 'Ana', currentClass: 'Amigo'),
      ];
  });

  Future<void> open(WidgetTester tester) {
    return pumpMembersApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        membersRepositoryProvider.overrideWithValue(repo),
      ],
      home: const MembersView(),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MembersView)));

  testWidgets('shows the skeleton while the members load', (tester) async {
    final gate = Completer<void>();
    repo.joinRequestsGate = gate;
    await open(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MembersListSkeleton), findsOneWidget);
    expect(find.byType(SacShimmer), findsOneWidget);
    expect(find.bySemanticsLabel('Cargando miembros'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);

    gate.complete();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(MembersListSkeleton), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('keeps the no-members copy when no filter is active', (
    tester,
  ) async {
    repo.members = const [];
    await open(tester);
    await tester.pumpAndSettle();

    expect(find.text('Sin miembros'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsNothing);
  });

  testWidgets('filtered-empty state clears the filters and the search', (
    tester,
  ) async {
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Nadie coincide con tu búsqueda'), findsOneWidget);
    expect(
      find.text('Prueba con otro nombre o quita los filtros de clase y cargo.'),
      findsOneWidget,
    );
    expect(find.text('Ana'), findsNothing);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(memberFiltersProvider).hasActiveFilters,
      isFalse,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('empty states keep pull-to-refresh available', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    final scrollable = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());
  });
}
