import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_abandon_menu_button.dart';
import '../../../../support/riverpod_test_support.dart';

/// No translations on purpose: the assertions read the raw keys.
class _NoTranslations extends AssetLoader {
  const _NoTranslations();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 'user-1', email: 'user@example.com');
}

class _RecordingAbandonNotifier extends HonorAbandonActionsNotifier {
  _RecordingAbandonNotifier({this.result = true});

  final bool result;
  final calls = <(String, int)>[];

  @override
  Future<void> build() async {}

  @override
  Future<bool> abandon({required String userId, required int honorId}) async {
    calls.add((userId, honorId));
    return result;
  }
}

UserHonor _userHonor(String status) => UserHonor(
      id: 77,
      honorId: 16,
      userId: 'user-1',
      completionMode: HonorCompletionMode.inApp,
      validationStatus: status,
      date: DateTime(2026, 6, 11),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  /// Pushes a work screen with the menu on top of a home route so a
  /// successful abandon can be observed as a pop.
  Future<void> pumpMenu(
    WidgetTester tester, {
    required UserHonor userHonor,
    required _RecordingAbandonNotifier notifier,
    String? progressSummary,
  }) async {
    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          honorAbandonActionsNotifierProvider.overrideWith(() => notifier),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const _NoTranslations(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('work-screen'),
                              actions: [
                                HonorAbandonMenuButton(
                                  userHonor: userHonor,
                                  honorName: 'Amarres',
                                  progressSummary: progressSummary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> openAbandonDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('honor-abandon-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('honors.abandon.action'));
    await tester.pumpAndSettle();
  }

  for (final status in ['PENDING_REVIEW', 'APPROVED']) {
    testWidgets('is hidden when the honor is $status', (tester) async {
      await pumpMenu(
        tester,
        userHonor: _userHonor(status),
        notifier: _RecordingAbandonNotifier(),
      );

      expect(find.byKey(const ValueKey('honor-abandon-menu')), findsNothing);
    });
  }

  testWidgets('asks for a destructive confirmation and can be cancelled',
      (tester) async {
    final notifier = _RecordingAbandonNotifier();
    await pumpMenu(tester,
        userHonor: _userHonor('IN_PROGRESS'), notifier: notifier);

    await openAbandonDialog(tester);

    expect(find.text('honors.abandon.confirm_title'), findsOneWidget);
    final confirmButton = tester.widget<SacButton>(
      find.ancestor(
        of: find.text('honors.abandon.confirm_cta'),
        matching: find.byType(SacButton),
      ),
    );
    expect(confirmButton.variant, SacButtonVariant.destructive);

    await tester.tap(find.text('core.dialog.cancel'));
    await tester.pumpAndSettle();

    expect(notifier.calls, isEmpty);
    expect(find.text('work-screen'), findsOneWidget);
  });

  testWidgets('opens the design-system pull-down, not a Material menu',
      (tester) async {
    await pumpMenu(tester,
        userHonor: _userHonor('IN_PROGRESS'),
        notifier: _RecordingAbandonNotifier());

    await tester.tap(find.byKey(const ValueKey('honor-abandon-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('honor-abandon-pull-down')), findsOne);
    expect(find.byType(PopupMenuItem), findsNothing);
    expect(find.text('honors.abandon.action_hint'), findsOneWidget);
    // The panel hangs from the button, but never flush with the screen edge.
    final panelRight = tester
        .getTopRight(find.byKey(const ValueKey('honor-abandon-pull-down')))
        .dx;
    final buttonRight = tester
        .getBottomRight(find.byKey(const ValueKey('honor-abandon-menu')))
        .dx;
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(panelRight, lessThanOrEqualTo(screenWidth - 12));
    expect(buttonRight - panelRight, inInclusiveRange(9, 12));

    // Tapping outside closes it without asking anything.
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('honor-abandon-pull-down')), findsNothing);
    expect(find.text('honors.abandon.confirm_title'), findsNothing);
  });

  testWidgets('the confirmation recalls the progress that would be lost',
      (tester) async {
    await pumpMenu(
      tester,
      userHonor: _userHonor('IN_PROGRESS'),
      notifier: _RecordingAbandonNotifier(),
      progressSummary: 'Llevas 3 de 5 requisitos (60 %)',
    );

    await openAbandonDialog(tester);

    expect(find.text('Llevas 3 de 5 requisitos (60 %)'), findsOneWidget);
  });

  testWidgets('abandons, shows success and leaves the work screen',
      (tester) async {
    final notifier = _RecordingAbandonNotifier();
    await pumpMenu(tester,
        userHonor: _userHonor('REJECTED'), notifier: notifier);

    await openAbandonDialog(tester);
    await tester.tap(find.text('honors.abandon.confirm_cta'));
    await tester.pumpAndSettle();

    expect(notifier.calls, [('user-1', 16)]);
    expect(find.text('honors.abandon.success'), findsOneWidget);
    expect(find.text('work-screen'), findsNothing);
  });

  testWidgets('shows an error and stays when the backend rejects it',
      (tester) async {
    final notifier = _RecordingAbandonNotifier(result: false);
    await pumpMenu(tester,
        userHonor: _userHonor('IN_PROGRESS'), notifier: notifier);

    await openAbandonDialog(tester);
    await tester.tap(find.text('honors.abandon.confirm_cta'));
    await tester.pumpAndSettle();

    expect(notifier.calls, hasLength(1));
    expect(find.text('honors.abandon.error'), findsOneWidget);
    expect(find.text('work-screen'), findsOneWidget);
  });
}
