import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/views/dashboard_view.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/birthday_celebration.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/club_info_card.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/current_class_card.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/membership_status_banner.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/quick_access_grid.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/upcoming_activities_card.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/welcome_header.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/enrollment/presentation/widgets/enrollment_status_card.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

class _LoadedDashboardNotifier extends DashboardNotifier {
  _LoadedDashboardNotifier(this.summary);

  final DashboardSummary summary;

  @override
  Future<DashboardSummary?> build() async => summary;
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final UserEntity user;

  @override
  Future<UserEntity?> build() async => user;
}

class _NullProfileNotifier extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

const _summary = DashboardSummary(
  userName: 'Ana',
  userAvatar: null,
  clubName: 'Club Central',
  clubType: 'Conquistadores',
  userRole: 'member',
  currentClassName: 'Guía',
  currentClassInvestitureStatus: 'active',
  currentClassId: null,
  classProgress: 0.4,
  honorsCompleted: 2,
  honorsInProgress: 1,
  upcomingActivities: [],
);

UserEntity _userWithPermissions(List<String> permissions) {
  const assignmentId = 'assignment-1';

  return UserEntity(
    id: 'user-1',
    email: 'ana@example.com',
    name: 'Ana',
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      activeAssignmentId: assignmentId,
      clubAssignments: const [
        AuthorizationGrant(
          assignmentId: assignmentId,
          roleName: 'member',
          clubId: 1,
          sectionId: 2,
          status: 'active',
        ),
      ],
    ),
  );
}

Future<void> _pumpLoadedDashboard(
  WidgetTester tester, {
  required List<String> permissions,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardNotifierProvider.overrideWith(
          () => _LoadedDashboardNotifier(_summary),
        ),
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(_userWithPermissions(permissions)),
        ),
        profileNotifierProvider.overrideWith(_NullProfileNotifier.new),
        currentEnrollmentProvider.overrideWith((ref) async => null),
        camporeeJudgeAssignmentsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: DashboardView()),
    ),
  );

  // Resolve the synchronous fixture without advancing animation time.
  await tester.pump();
  expect(find.byType(WelcomeHeader), findsOneWidget);
}

List<T> _dashboardCompositionAncestors<T extends Widget>(
  WidgetTester tester,
  Finder finder,
) {
  final ancestors = <T>[];
  tester.element(finder).visitAncestorElements((element) {
    if (element.widget is DashboardView) {
      return false;
    }
    if (element.widget case final T widget) {
      ancestors.add(widget);
    }
    return true;
  });
  return ancestors;
}

Column _loadedSectionsColumn(WidgetTester tester) {
  return tester.widgetList<Column>(find.byType(Column)).singleWhere(
        (column) =>
            column.children.any((child) => child is MembershipStatusBanner),
      );
}

void main() {
  testWidgets(
    'renders late dashboard content fully stable on the first loaded frame',
    (tester) async {
      await _pumpLoadedDashboard(
        tester,
        permissions: const ['reports:read'],
      );

      final functionalSections = <Finder>[
        find.byType(WelcomeHeader),
        find.byType(BirthdayCelebrationGate),
        find.byType(QuickAccessGrid),
        find.byType(UpcomingActivitiesCard),
      ];

      for (final section in functionalSections) {
        expect(section, findsOneWidget);

        expect(
          _dashboardCompositionAncestors<StaggeredListItem>(tester, section),
          isEmpty,
          reason: '$section must not be wrapped in dashboard-owned stagger',
        );
        expect(
          _dashboardCompositionAncestors<StaggeredColumn>(tester, section),
          isEmpty,
          reason: '$section must not be inside a dashboard-owned stagger',
        );

        for (final fade in _dashboardCompositionAncestors<FadeTransition>(
          tester,
          section,
        )) {
          expect(
            fade.opacity.value,
            1,
            reason: '$section must not wait for an entrance fade',
          );
        }
        for (final slide in _dashboardCompositionAncestors<SlideTransition>(
          tester,
          section,
        )) {
          expect(
            slide.position.value,
            Offset.zero,
            reason: '$section must not wait for an entrance slide',
          );
        }
      }
    },
  );

  for (final permissionCase in <({String name, List<String> permissions})>[
    (name: 'without optional permissions', permissions: const []),
    (name: 'with reports permission', permissions: const ['reports:read']),
  ]) {
    testWidgets(
      'preserves loaded section order and spacing ${permissionCase.name}',
      (tester) async {
        await _pumpLoadedDashboard(
          tester,
          permissions: permissionCase.permissions,
        );

        final outerColumn =
            tester.widgetList<Column>(find.byType(Column)).singleWhere(
                  (column) =>
                      column.children.length == 2 &&
                      column.children.first is WelcomeHeader &&
                      column.children.last is Padding,
                );
        expect(outerColumn.crossAxisAlignment, CrossAxisAlignment.start);

        final children = _loadedSectionsColumn(tester).children;
        expect(children, hasLength(12));
        expect(children[0], isA<MembershipStatusBanner>());
        expect(children[1], isA<EnrollmentStatusCard>());
        expect(children[2], isA<BirthdayCelebrationGate>());
        expect((children[3] as SizedBox).height, 16);
        expect(children[4], isA<ClubInfoCard>());
        expect((children[5] as SizedBox).height, 16);
        expect(children[6], isA<CurrentClassCard>());
        expect((children[7] as SizedBox).height, 16);
        expect(children[8], isA<QuickAccessGrid>());
        expect((children[9] as SizedBox).height, 16);
        expect(children[10], isA<UpcomingActivitiesCard>());
        expect((children[11] as SizedBox).height, 24);
        expect(
          find.text('Demo temporal de animaciones'),
          findsNothing,
          reason: 'the temporary motion launcher is intentionally hidden',
        );

        final reportsShortcut = find.text('dashboard.quick_access.reports');
        expect(
          reportsShortcut,
          permissionCase.permissions.contains('reports:read')
              ? findsOneWidget
              : findsNothing,
        );
      },
    );
  }
}
