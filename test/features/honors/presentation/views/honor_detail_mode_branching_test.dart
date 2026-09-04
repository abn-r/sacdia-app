import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _RecordingCompletionModeNotifier
    extends HonorCompletionModeActionsNotifier {
  int callCount = 0;
  String? capturedUserId;
  int? capturedHonorId;
  HonorCompletionMode? capturedMode;

  @override
  Future<UserHonor?> build() async => null;

  @override
  Future<bool> updateCompletionMode({
    required String userId,
    required int honorId,
    required HonorCompletionMode completionMode,
  }) async {
    callCount += 1;
    capturedUserId = userId;
    capturedHonorId = honorId;
    capturedMode = completionMode;
    state = AsyncValue.data(
      UserHonor(
        id: 77,
        honorId: honorId,
        userId: userId,
        completionMode: completionMode,
        validationStatus: 'IN_PROGRESS',
        date: DateTime(2026, 6, 11),
      ),
    );
    return true;
  }
}

void main() {
  Honor honor() {
    return const Honor(
      id: 7,
      name: 'Arte de acampar',
      categoryId: 1,
      approval: 1,
      clubTypeId: 1,
      materialUrl: 'https://example.com/form.pdf',
    );
  }

  UserHonor userHonor(
    HonorCompletionMode mode, {
    String validationStatus = 'IN_PROGRESS',
    DateTime? submittedAt,
    String? validatedById,
    String? validatedByName,
    String? validatedByRoleName,
    String? validatedByRoleLabel,
    DateTime? validatedAt,
    String? document,
    List<String> images = const [],
  }) {
    return UserHonor(
      id: 77,
      honorId: 7,
      userId: 'user-1',
      completionMode: mode,
      validationStatus: validationStatus,
      document: document,
      images: images,
      date: DateTime(2026, 6, 11),
      submittedAt: submittedAt,
      validatedById: validatedById,
      validatedByName: validatedByName,
      validatedByRoleName: validatedByRoleName,
      validatedByRoleLabel: validatedByRoleLabel,
      validatedAt: validatedAt,
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    HonorCompletionMode mode, {
    String validationStatus = 'IN_PROGRESS',
    UserHonor? userHonorOverride,
    List<UserHonorRequirementProgress> progress = const [],
    List<Override> extraOverrides = const [],
    bool watchAuth = false,
  }) async {
    final currentHonor = honor();
    final currentUserHonor = userHonorOverride ??
        userHonor(mode, validationStatus: validationStatus);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          honorCategoriesProvider.overrideWith(
            (ref) async => const <HonorCategory>[],
          ),
          allHonorsProvider.overrideWith((ref) async => [currentHonor]),
          activeHonorCatalogClubTypeIdProvider.overrideWith(
            (ref) => const AsyncValue.data(null),
          ),
          userHonorsProvider.overrideWith(
            (ref) async => [
              currentUserHonor,
            ],
          ),
          userHonorProgressProvider(currentHonor.id).overrideWith(
            (ref) async => progress,
          ),
          ...extraOverrides,
        ],
        child: MaterialApp(
          home: watchAuth
              ? Consumer(
                  builder: (context, ref, child) {
                    ref.watch(authNotifierProvider);
                    return child!;
                  },
                  child: HonorDetailView(
                    honorId: currentHonor.id,
                    initialHonor: currentHonor,
                  ),
                )
              : HonorDetailView(
                  honorId: currentHonor.id,
                  initialHonor: currentHonor,
                ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('undecided mode shows selector and no workflow CTA',
      (tester) async {
    await pumpDetail(tester, HonorCompletionMode.undecided);

    expect(find.text('honors.work_mode.title'), findsOneWidget);
    expect(find.text('honors.detail.select_mode_cta'), findsOneWidget);
    expect(find.text('honors.detail.continue_requirements_cta'), findsNothing);
    expect(find.text('honors.detail.external_flow_cta'), findsNothing);
  });

  testWidgets(
      'pending review with undecided mode does not allow mode selection',
      (tester) async {
    await pumpDetail(
      tester,
      HonorCompletionMode.undecided,
      validationStatus: 'PENDING_REVIEW',
    );

    expect(find.text('honors.work_mode.title'), findsNothing);
    expect(find.text('honors.detail.work_mode_locked_title'), findsOneWidget);
    expect(
      find.text('honors.detail.work_mode_locked_under_review'),
      findsOneWidget,
    );
    expect(find.text('honors.detail.change_work_mode_cta'), findsNothing);
  });

  testWidgets('approved honor shows validation history instead of locked mode',
      (tester) async {
    await pumpDetail(
      tester,
      HonorCompletionMode.undecided,
      validationStatus: 'APPROVED',
      userHonorOverride: userHonor(
        HonorCompletionMode.undecided,
        validationStatus: 'APPROVED',
        submittedAt: DateTime(2026, 6, 12, 9, 30),
        validatedAt: DateTime(2026, 6, 13, 16, 45),
        validatedByName: 'Directora Local',
        validatedByRoleName: 'director',
        validatedByRoleLabel: 'Director',
        images: const ['https://example.com/evidence.jpg'],
      ),
    );

    expect(find.text('honors.detail.work_mode_locked_title'), findsNothing);
    expect(find.text('honors.detail.validation_history_title'), findsOneWidget);
    expect(find.text('honors.detail.mode_external_legacy'), findsOneWidget);
    expect(find.text('Directora Local'), findsOneWidget);
    expect(find.text('Director'), findsOneWidget);
    expect(find.text('honors.detail.status_validated'), findsOneWidget);
  });

  testWidgets('in-app mode shows requirements CTA only', (tester) async {
    await pumpDetail(tester, HonorCompletionMode.inApp);

    expect(
        find.text('honors.detail.continue_requirements_cta'), findsOneWidget);
    expect(find.text('honors.detail.change_work_mode_cta'), findsOneWidget);
    expect(find.text('honors.detail.external_flow_cta'), findsNothing);
  });

  testWidgets('pending review with selected mode hides change mode action',
      (tester) async {
    await pumpDetail(
      tester,
      HonorCompletionMode.inApp,
      validationStatus: 'PENDING_REVIEW',
    );

    expect(find.text('honors.detail.under_review_cta'), findsOneWidget);
    expect(find.text('honors.detail.change_work_mode_cta'), findsNothing);
  });

  testWidgets('approved in-app honor shows requirement responses and evidences',
      (tester) async {
    await pumpDetail(
      tester,
      HonorCompletionMode.inApp,
      validationStatus: 'APPROVED',
      userHonorOverride: userHonor(
        HonorCompletionMode.inApp,
        validationStatus: 'APPROVED',
        validatedById: 'validator-1',
        validatedAt: DateTime(2026, 6, 13, 16, 45),
      ),
      progress: [
        UserHonorRequirementProgress(
          requirementId: 101,
          requirementNumber: 1,
          text: 'Explica lo aprendido',
          completed: true,
          completedAt: DateTime(2026, 6, 12, 10),
          textResponse: 'Aprendí a documentar mi trabajo.',
          evidences: const [
            RequirementEvidence(
              id: 1,
              evidenceType: EvidenceType.file,
              url: 'https://example.com/evidence.pdf',
              filename: 'evidence.pdf',
            ),
          ],
        ),
      ],
    );

    expect(find.text('honors.detail.work_mode_locked_title'), findsNothing);
    expect(
      find.text('honors.detail.requirements_history_title'),
      findsOneWidget,
    );
    expect(find.text('validator-1'), findsNothing);
    expect(find.text('Aprendí a documentar mi trabajo.'), findsOneWidget);
    expect(find.text('evidence.pdf'), findsOneWidget);
  });

  testWidgets('external mode shows external flow CTA only', (tester) async {
    await pumpDetail(tester, HonorCompletionMode.external);

    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('honors.detail.external_flow_cta'), findsOneWidget);
    expect(find.text('honors.detail.change_work_mode_cta'), findsOneWidget);
    expect(find.text('honors.detail.external_mode_title'), findsOneWidget);
    expect(find.text('honors.detail.mode_external'), findsOneWidget);
    expect(find.text('honors.detail.continue_requirements_cta'), findsNothing);
    expect(find.text('honors.detail.complete_requirements'), findsNothing);
  });

  testWidgets(
      'pending review with external mode hides change mode and evidence CTA',
      (tester) async {
    await pumpDetail(
      tester,
      HonorCompletionMode.external,
      validationStatus: 'PENDING_REVIEW',
    );

    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('honors.detail.under_review_cta'), findsOneWidget);
    expect(find.text('honors.detail.change_work_mode_cta'), findsNothing);
    expect(find.text('honors.detail.external_flow_cta'), findsNothing);
  });

  testWidgets('confirms before saving the selected work mode', (tester) async {
    final recorder = _RecordingCompletionModeNotifier();

    await pumpDetail(
      tester,
      HonorCompletionMode.undecided,
      extraOverrides: [
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(
            const UserEntity(id: 'user-1', email: 'user@example.com'),
          ),
        ),
        honorCompletionModeActionsNotifierProvider.overrideWith(() => recorder),
      ],
    );

    await tester.ensureVisible(find.text('honors.work_mode.in_app_title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('honors.work_mode.in_app_title'));
    await tester.pumpAndSettle();

    expect(find.text('honors.work_mode.confirm_title'), findsNothing);
    expect(recorder.callCount, 0);

    await tester.tap(find.text('honors.work_mode.continue_cta'));
    await tester.pumpAndSettle();

    expect(find.text('honors.work_mode.confirm_title'), findsOneWidget);
    expect(recorder.callCount, 0);

    await tester.tap(find.text('core.dialog.cancel'));
    await tester.pumpAndSettle();

    expect(find.text('honors.work_mode.confirm_title'), findsNothing);
    expect(recorder.callCount, 0);

    await tester.ensureVisible(find.text('honors.work_mode.external_title'));
    await tester.tap(find.text('honors.work_mode.external_title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('honors.work_mode.continue_cta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('common.confirm'));
    await tester.pumpAndSettle();

    expect(recorder.callCount, 1);
    expect(recorder.capturedUserId, 'user-1');
    expect(recorder.capturedHonorId, 7);
    expect(recorder.capturedMode, HonorCompletionMode.external);
    expect(find.text('honors.work_mode.title'), findsNothing);
    expect(find.text('honors.detail.external_flow_cta'), findsOneWidget);
    expect(find.byType(SliverAppBar), findsNothing);
  });
}
