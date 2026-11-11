import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/sac_font_size.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/enrollment/presentation/widgets/enrollment_status_card.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import '../../../../support/riverpod_test_support.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

UserEntity _user({
  required String roleName,
  required List<String> permissions,
  PrincipalInfo? principal,
}) {
  const activeAssignmentId = 'assignment-1';

  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    principal: principal,
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      activeAssignmentId: activeAssignmentId,
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: activeAssignmentId,
          roleName: roleName,
          clubId: 1,
          sectionId: 2,
          status: 'active',
        ),
      ],
    ),
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  UserEntity user, {
  Enrollment? enrollment,
  bool showTask = true,
}) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        clubContextProvider.overrideWith(
          (ref) async => const ClubContext(
            clubId: 1,
            sectionId: 2,
            roleName: 'director',
          ),
        ),
        currentEnrollmentProvider.overrideWith((ref) async => enrollment),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EnrollmentStatusCard(showTask: showTask),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

const _activeEnrollment = Enrollment(
  id: 100,
  enrollmentUuid: '11111111-1111-4111-8111-111111111111',
  userId: 'user-1',
  clubSectionId: 2,
  year: 2026,
  address: 'Templo Central',
  meetingDays: ['Sábado'],
  status: EnrollmentStatus.active,
);

const _pendingValidationEnrollment = Enrollment(
  id: 101,
  enrollmentUuid: '22222222-2222-4222-8222-222222222222',
  userId: 'user-1',
  clubSectionId: 2,
  year: 2026,
  address: 'Templo Central',
  meetingDays: ['Sábado'],
  status: EnrollmentStatus.pendingValidation,
);

void main() {
  group('EnrollmentStatusCard', () {
    testWidgets('stays hidden for a supervised teen', (tester) async {
      await _pumpCard(
        tester,
        _user(
          roleName: 'member',
          permissions: const ['club_instances:read'],
          principal: const PrincipalInfo(
            kind: PrincipalKind.supervisedUser,
            supervision: SupervisionInfo(status: SupervisionStatus.active),
          ),
        ),
      );

      expect(find.text('enrollment.status.title_pending'), findsNothing);
    });

    testWidgets(
      'shows enrollment action for canonical club instance creators',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'director',
            permissions: const ['club_instances:create'],
          ),
        );

        expect(find.text('enrollment.status.title_pending'), findsOneWidget);
        expect(
          find.text('enrollment.status.subtitle_pending_action'),
          findsOneWidget,
        );
        // The whole card is the action, announced with the enroll label.
        expect(tester.widget<SacCard>(find.byType(SacCard)).onTap, isNotNull);
        expect(
          find.bySemanticsLabel(RegExp('enrollment.status.button_enroll')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'leaves the enrollment task to «Pendientes» when showTask is false',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'director',
            permissions: const ['club_instances:create'],
          ),
          showTask: false,
        );

        expect(find.byType(SacCard), findsNothing);
        expect(find.text('enrollment.status.title_pending'), findsNothing);
      },
    );

    testWidgets(
      'keeps the submitted state visible when showTask is false',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'director',
            permissions: const ['club_instances:create'],
          ),
          enrollment: _pendingValidationEnrollment,
          showTask: false,
        );

        expect(find.text('enrollment.status.title_submitted'), findsOneWidget);
      },
    );

    testWidgets(
      'keeps the enrollment action hidden for members without create permission',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'member',
            permissions: const ['club_instances:read'],
          ),
        );

        expect(find.text('enrollment.status.title_pending'), findsOneWidget);
        expect(tester.widget<SacCard>(find.byType(SacCard)).onTap, isNull);
        expect(
          find.text('enrollment.status.subtitle_pending_viewer'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows submitted validation state while annual enrollment awaits Campo Local validation',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'director',
            permissions: const ['club_instances:create'],
          ),
          enrollment: _pendingValidationEnrollment,
        );

        expect(find.text('enrollment.status.title_submitted'), findsOneWidget);
        expect(
          find.text('enrollment.status.subtitle_submitted'),
          findsOneWidget,
        );
        expect(tester.widget<SacCard>(find.byType(SacCard)).onTap, isNull);
      },
    );

    testWidgets(
      'renders submitted validation state like the dashboard pending card',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'director',
            permissions: const ['club_instances:create'],
          ),
          enrollment: _pendingValidationEnrollment,
        );

        // Neutral card, not a yellow banner.
        expect(find.byType(SacCard), findsOneWidget);

        final iconWell = tester.widgetList<Container>(
          find.byWidgetPredicate((widget) {
            if (widget is! Container) return false;
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.color ==
                    const SacColors(Brightness.light).warningContainer &&
                widget.constraints?.maxWidth == 36 &&
                widget.constraints?.maxHeight == 36;
          }),
        );
        expect(iconWell, isNotEmpty);

        final title = tester.widget<Text>(
          find.text('enrollment.status.title_submitted'),
        );
        expect(title.style?.color, AppColors.lightText);
        expect(title.style?.fontSize, SacFontSize.titleMedium);
        expect(title.style?.fontWeight, FontWeight.w600);
      },
    );

    testWidgets(
      'does not show Campo Local validation message after annual enrollment is active',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'director',
            permissions: const ['club_instances:create'],
          ),
          enrollment: _activeEnrollment,
        );

        expect(find.text('enrollment.status.title_submitted'), findsNothing);
        expect(find.text('enrollment.status.button_enroll'), findsNothing);
      },
    );
  });
}
