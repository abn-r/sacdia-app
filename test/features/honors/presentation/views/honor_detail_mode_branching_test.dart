import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
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

  UserHonor userHonor(HonorCompletionMode mode) {
    return UserHonor(
      id: 77,
      honorId: 7,
      userId: 'user-1',
      completionMode: mode,
      validationStatus: 'IN_PROGRESS',
      date: DateTime(2026, 6, 11),
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    HonorCompletionMode mode, {
    List<Override> extraOverrides = const [],
    bool watchAuth = false,
  }) async {
    final currentHonor = honor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          honorCategoriesProvider.overrideWith(
            (ref) async => const <HonorCategory>[],
          ),
          allHonorsProvider.overrideWith((ref) async => [currentHonor]),
          userHonorsProvider.overrideWith((ref) async => [userHonor(mode)]),
          userHonorProgressProvider(currentHonor.id).overrideWith(
            (ref) async => const <UserHonorRequirementProgress>[],
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

  testWidgets('in-app mode shows requirements CTA only', (tester) async {
    await pumpDetail(tester, HonorCompletionMode.inApp);

    expect(
        find.text('honors.detail.continue_requirements_cta'), findsOneWidget);
    expect(find.text('honors.detail.change_work_mode_cta'), findsOneWidget);
    expect(find.text('honors.detail.external_flow_cta'), findsNothing);
  });

  testWidgets('external mode shows external flow CTA only', (tester) async {
    await pumpDetail(tester, HonorCompletionMode.external);

    expect(find.text('honors.detail.external_flow_cta'), findsWidgets);
    expect(find.text('honors.detail.change_work_mode_cta'), findsOneWidget);
    expect(find.text('honors.detail.continue_requirements_cta'), findsNothing);
    expect(find.text('honors.detail.complete_requirements'), findsNothing);
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

    expect(find.text('honors.work_mode.confirm_title'), findsOneWidget);
    expect(recorder.callCount, 0);

    await tester.tap(find.text('common.cancel'));
    await tester.pumpAndSettle();

    expect(find.text('honors.work_mode.confirm_title'), findsNothing);
    expect(recorder.callCount, 0);

    await tester.ensureVisible(find.text('honors.work_mode.external_title'));
    await tester.tap(find.text('honors.work_mode.external_title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('common.confirm'));
    await tester.pumpAndSettle();

    expect(recorder.callCount, 1);
    expect(recorder.capturedUserId, 'user-1');
    expect(recorder.capturedHonorId, 7);
    expect(recorder.capturedMode, HonorCompletionMode.external);
    expect(find.text('honors.work_mode.title'), findsNothing);
    expect(find.text('honors.detail.external_flow_cta'), findsWidgets);
  });
}
