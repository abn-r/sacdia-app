import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/enrollment/presentation/widgets/enrollment_status_card.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

UserEntity _user({
  required String roleName,
  required List<String> permissions,
}) {
  const activeAssignmentId = 'assignment-1';

  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
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
      child: const MaterialApp(
        home: Scaffold(
          body: EnrollmentStatusCard(),
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
        expect(find.text('enrollment.status.button_enroll'), findsOneWidget);
        expect(
          find.text('enrollment.status.subtitle_pending_action'),
          findsOneWidget,
        );
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
        expect(find.text('enrollment.status.button_enroll'), findsNothing);
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
        expect(find.text('enrollment.status.button_enroll'), findsNothing);
      },
    );

    testWidgets(
      'renders submitted validation state as a compact yellow banner',
      (tester) async {
        await _pumpCard(
          tester,
          _user(
            roleName: 'director',
            permissions: const ['club_instances:create'],
          ),
          enrollment: _pendingValidationEnrollment,
        );

        final submittedBanner = tester.widgetList<Container>(
          find.byWidgetPredicate((widget) {
            if (widget is! Container) return false;
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.color == AppColors.accentLight &&
                widget.padding == const EdgeInsets.all(12.8);
          }),
        );

        expect(submittedBanner, isNotEmpty);

        final submittedIconBox = tester.widgetList<Container>(
          find.byWidgetPredicate((widget) {
            if (widget is! Container) return false;
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.color == AppColors.accent.withValues(alpha: 0.2) &&
                widget.constraints?.maxWidth == 32 &&
                widget.constraints?.maxHeight == 32;
          }),
        );

        expect(submittedIconBox, isNotEmpty);

        final title = tester.widget<Text>(
          find.text('enrollment.status.title_submitted'),
        );
        expect(title.style?.color, AppColors.accentDark);
        expect(title.style?.fontSize, closeTo(11.2, 0.001));
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
