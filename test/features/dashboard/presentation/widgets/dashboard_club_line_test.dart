import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/dashboard_club_line.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import '../../../../support/riverpod_test_support.dart';

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

UserEntity _user({
  required List<AuthorizationGrant> assignments,
  String? activeAssignmentId = 'a-1',
}) {
  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    authorization: AuthorizationSnapshot(
      activeAssignmentId: activeAssignmentId,
      clubAssignments: assignments,
    ),
  );
}

const _active = AuthorizationGrant(
  assignmentId: 'a-1',
  roleName: 'director',
  clubId: 1,
  sectionId: 2,
  clubName: 'ACV',
  clubTypeName: 'Aventureros',
  status: 'active',
);

const _other = AuthorizationGrant(
  assignmentId: 'a-2',
  roleName: 'counselor',
  clubId: 1,
  sectionId: 3,
  clubName: 'ACV',
  clubTypeName: 'Conquistadores',
  status: 'active',
);

Future<void> _pump(
  WidgetTester tester,
  UserEntity user, {
  String? clubName,
}) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        profileNotifierProvider.overrideWith(_NullProfileNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(body: DashboardClubLine(clubName: clubName)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _chevron => find.byWidgetPredicate(
      (widget) =>
          widget is HugeIcon &&
          widget.icon == HugeIcons.strokeRoundedArrowDown01,
    );

void main() {
  group('DashboardClubLine', () {
    testWidgets('single assignment: label and logo, no chevron, not a button',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _user(assignments: const [_active]));

      expect(find.text('ACV · Aventureros'), findsOneWidget);
      final logo = tester.widget<Image>(find.byType(Image));
      final provider = logo.image;
      final asset = provider is ResizeImage
          ? provider.imageProvider as AssetImage
          : provider as AssetImage;
      expect(asset.assetName, 'assets/img/logo_aventureros.png');
      expect(_chevron, findsNothing);

      // Tapping does nothing: no sheet opens.
      await tester.tap(find.text('ACV · Aventureros'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      handle.dispose();
    });

    testWidgets('dashboard summary club name wins over the grant name',
        (tester) async {
      await _pump(
        tester,
        _user(assignments: const [_active]),
        clubName: 'Club Central',
      );

      expect(find.text('Club Central · Aventureros'), findsOneWidget);
    });

    testWidgets('multiple assignments: chevron, button semantics, opens sheet',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _user(assignments: const [_active, _other]));

      expect(_chevron, findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'dashboard.club_line.switch_semantics',
        ),
        findsOneWidget,
      );
      // At least 44dp tall so it is a comfortable touch target.
      expect(
        tester.getSize(find.byType(DashboardClubLine)).height,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(find.text('ACV · Aventureros'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a second assignment that is not usable gives no chevron',
        (tester) async {
      const pending = AuthorizationGrant(
        assignmentId: 'a-2',
        roleName: 'member',
        clubName: 'Other',
        clubTypeName: 'Conquistadores',
        status: 'pending',
      );
      await _pump(tester, _user(assignments: const [_active, pending]));

      expect(find.text('ACV · Aventureros'), findsOneWidget);
      expect(_chevron, findsNothing);
    });

    testWidgets('renders nothing without an active club grant', (tester) async {
      await _pump(
        tester,
        _user(assignments: const [_other], activeAssignmentId: null),
        clubName: 'Club Central',
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  });
}
