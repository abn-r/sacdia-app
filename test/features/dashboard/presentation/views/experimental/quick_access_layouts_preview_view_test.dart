import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/views/experimental/quick_access_layouts_preview_view.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/experimental/quick_access_compact_grid.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/quick_access_items.dart';
import '../../../../../support/riverpod_test_support.dart';

// Keeps the experimental layouts (options C and D of the 2026-11 home
// redesign) compiled and exercised even though no route reaches them.

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

UserEntity _director() {
  return const UserEntity(
    id: 'user-1',
    email: 'director@example.com',
    authorization: AuthorizationSnapshot(
      effectivePermissions: [
        'users:read_detail',
        'clubs:update',
        'units:update',
        'classes:submit_progress',
        'evidence_folders:read',
        'camporees:read',
        'rankings:read',
        'finances:read',
        'insurance:read',
        'inventory:read',
        'materiales:create',
        'reports:read',
        'resources:read',
      ],
      globalGrants: [AuthorizationGrant(roleName: 'pastor')],
      activeAssignmentId: 'a-1',
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: 'a-1',
          roleName: 'director',
          clubId: 1,
          sectionId: 2,
          status: 'active',
        ),
      ],
    ),
  );
}

Future<void> _pumpPreview(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(_director())),
        camporeeJudgeAssignmentsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: QuickAccessLayoutsPreviewView()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('renders option C and option D with the director launcher',
      (tester) async {
    await _pumpPreview(tester);

    expect(find.byType(QuickAccessCompactGrid), findsOneWidget);
    expect(find.byType(QuickAccessGroupedGrid), findsOneWidget);

    // Option C: title + one tile per visible item.
    expect(find.text('dashboard.quick_access.title'), findsOneWidget);
    // Option D: the three group headers.
    expect(find.text('dashboard.quick_access.group_club'), findsOneWidget);
    expect(find.text('dashboard.quick_access.group_training'), findsOneWidget);
    expect(find.text('dashboard.quick_access.group_admin'), findsOneWidget);

    // Both layouts show every permitted destination (same source of truth).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuickAccessLayoutsPreviewView)),
    );
    final items = container.read(visibleQuickAccessItemsProvider);
    expect(items, isNotEmpty);
    expect(find.byType(SacCard), findsNWidgets(items.length * 2));
    for (final item in items) {
      expect(
        find.text(item.labelKey),
        findsNWidgets(2),
        reason: item.labelKey,
      );
    }
  });

  test('groups destinations into Club, Formación and Administración', () {
    QuickAccessItem item(String route) => QuickAccessItem(
          labelKey: route,
          icon: HugeIcons.strokeRoundedUserGroup,
          route: route,
        );

    final groups = groupQuickAccessItems([
      item(RouteNames.homeMembers),
      item(RouteNames.homeUnits),
      item(RouteNames.homeClub),
      item(RouteNames.homeGroupedClass),
      item(RouteNames.homeEvidences),
      item(RouteNames.sectionInvestiture),
      item(RouteNames.investitureAuthorize),
      item(RouteNames.homeClubRankings),
      item(RouteNames.homeCamporees),
      item(RouteNames.camporeeJudgeAssignments),
      item(RouteNames.homeResources),
      item(RouteNames.homeFinances),
      item(RouteNames.homeInsurance),
      item(RouteNames.homeInventory),
      item(RouteNames.homeMaterials),
      item(RouteNames.homeReports),
    ]);

    expect(groups.map((g) => g.titleKey), [
      'dashboard.quick_access.group_club',
      'dashboard.quick_access.group_training',
      'dashboard.quick_access.group_admin',
    ]);
    expect(groups.map((g) => g.items.length), [3, 8, 5]);
  });

  test('empty groups are omitted', () {
    final groups = groupQuickAccessItems([
      const QuickAccessItem(
        labelKey: 'reports',
        icon: HugeIcons.strokeRoundedAnalytics01,
        route: RouteNames.homeReports,
      ),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.titleKey, 'dashboard.quick_access.group_admin');
  });
}
