import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/sac_font_size.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_notice.dart';
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

const _boardRoles = {
  'director',
  'deputy-director',
  'secretary',
  'treasurer',
  'secretary-treasurer',
};

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
      // The server grants the club board capability to these roles only.
      capabilities: _boardRoles.contains(roleName)
          ? const ['club.administrative_staff']
          : const [],
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

const _rejectedEnrollment = Enrollment(
  id: 102,
  enrollmentUuid: '33333333-3333-4333-8333-333333333333',
  userId: 'user-1',
  clubSectionId: 2,
  year: 2026,
  address: 'Templo Central',
  meetingDays: ['Sábado'],
  status: EnrollmentStatus.rejected,
  decisionReason: 'Falta la dirección completa',
);

const _inactiveEnrollment = Enrollment(
  id: 103,
  enrollmentUuid: '44444444-4444-4444-8444-444444444444',
  userId: 'user-1',
  clubSectionId: 2,
  year: 2026,
  address: 'Templo Central',
  meetingDays: ['Sábado'],
  status: EnrollmentStatus.inactive,
);

UserEntity _director() => _user(
      roleName: 'director',
      permissions: const ['club_instances:create'],
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

    for (final role in ['member', 'counselor', 'instructor']) {
      testWidgets('stays hidden for a club $role (not the board)',
          (tester) async {
        await _pumpCard(
          tester,
          _user(roleName: role, permissions: const ['club_instances:read']),
          enrollment: _pendingValidationEnrollment,
        );

        expect(find.text('enrollment.status.title_submitted'), findsNothing);
        expect(find.byType(SacCard), findsNothing);
      });
    }

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
      'keeps the enrollment action hidden for board members without create permission',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'treasurer',
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

    testWidgets(
      'rejected: shows the reason in an error notice and the resubmit action',
      (tester) async {
        await _pumpCard(tester, _director(), enrollment: _rejectedEnrollment);

        expect(find.text('enrollment.status.title_rejected'), findsOneWidget);
        expect(find.text('enrollment.status.title_pending'), findsNothing);
        final notice = tester.widget<SacNotice>(find.byType(SacNotice));
        expect(notice.tone, SacNoticeTone.error);
        expect(notice.text, 'enrollment.status.rejection_reason');
        expect(tester.widget<SacCard>(find.byType(SacCard)).onTap, isNotNull);
        expect(
          find.bySemanticsLabel(RegExp('enrollment.status.button_resubmit')),
          findsOneWidget,
        );
      },
    );

    testWidgets('rejected without a reason shows no notice', (tester) async {
      await _pumpCard(
        tester,
        _director(),
        enrollment: const Enrollment(
          id: 104,
          userId: 'user-1',
          clubSectionId: 2,
          year: 2026,
          meetingDays: ['Sábado'],
          status: EnrollmentStatus.rejected,
        ),
      );

      expect(find.text('enrollment.status.title_rejected'), findsOneWidget);
      expect(find.byType(SacNotice), findsNothing);
    });

    testWidgets('rejected is left to «Pendientes» when showTask is false',
        (tester) async {
      await _pumpCard(
        tester,
        _director(),
        enrollment: _rejectedEnrollment,
        showTask: false,
      );

      expect(find.byType(SacCard), findsNothing);
    });

    testWidgets(
      'rejected for a viewer is read-only: no action and no reason',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'treasurer',
            permissions: const ['club_instances:read'],
          ),
          enrollment: _rejectedEnrollment,
        );

        expect(find.text('enrollment.status.title_rejected'), findsOneWidget);
        expect(
          find.text('enrollment.status.subtitle_rejected_viewer'),
          findsOneWidget,
        );
        expect(find.byType(SacNotice), findsNothing);
        expect(tester.widget<SacCard>(find.byType(SacCard)).onTap, isNull);
      },
    );

    testWidgets('inactive keeps the «requires attention» card', (tester) async {
      await _pumpCard(tester, _director(), enrollment: _inactiveEnrollment);

      expect(find.text('enrollment.status.title_pending'), findsOneWidget);
      expect(
        find.text('enrollment.status.subtitle_inactive_action'),
        findsOneWidget,
      );
      expect(find.text('enrollment.status.title_rejected'), findsNothing);
      expect(find.byType(SacNotice), findsNothing);
    });

    testWidgets('closed shows nothing', (tester) async {
      await _pumpCard(
        tester,
        _director(),
        enrollment: const Enrollment(
          id: 105,
          userId: 'user-1',
          clubSectionId: 2,
          year: 2025,
          meetingDays: ['Sábado'],
          status: EnrollmentStatus.closed,
        ),
      );

      expect(find.byType(SacCard), findsNothing);
    });
  });

  group('annualEnrollmentTaskProvider', () {
    Future<AnnualEnrollmentTask?> taskFor(
      WidgetTester tester,
      Enrollment? enrollment,
    ) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        testProviderScope(
          overrides: [
            authNotifierProvider
                .overrideWith(() => _FakeAuthNotifier(_director())),
            currentEnrollmentProvider.overrideWith((ref) async => enrollment),
          ],
          child: Consumer(builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            ref.watch(annualEnrollmentTaskProvider);
            return const SizedBox.shrink();
          }),
        ),
      );
      await tester.pumpAndSettle();
      return container.read(annualEnrollmentTaskProvider);
    }

    testWidgets('rejected is a resubmit task carrying the reason',
        (tester) async {
      final task = await taskFor(tester, _rejectedEnrollment);

      expect(task, isNotNull);
      expect(task!.isRejected, isTrue);
      expect(task.isResubmit, isTrue);
      expect(task.enrollmentId, _rejectedEnrollment.endpointId);
      expect(task.rejectionReason, 'Falta la dirección completa');
    });

    testWidgets('inactive is a resubmit task that is not a rejection',
        (tester) async {
      final task = await taskFor(tester, _inactiveEnrollment);

      expect(task!.isResubmit, isTrue);
      expect(task.isRejected, isFalse);
    });

    testWidgets('pending validation and approved are no task', (tester) async {
      expect(await taskFor(tester, _pendingValidationEnrollment), isNull);
      expect(await taskFor(tester, _activeEnrollment), isNull);
    });

    testWidgets('no enrollment is a create task', (tester) async {
      final task = await taskFor(tester, null);

      expect(task!.isResubmit, isFalse);
      expect(task.isRejected, isFalse);
    });
  });
}
