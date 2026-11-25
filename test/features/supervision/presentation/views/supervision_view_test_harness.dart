/// Shared harness for the supervision queue views (enrollments, requests):
/// real Spanish translations, a minimal router, a user with capabilities and
/// a fake auth notifier.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../../coordinator/coordinator_test_harness.dart';

const kSupervisionAppView = 'supervision.app_view';
const kValidateCap = 'club_enrollments.validate';
const kReviewCap = 'requests.review_territory';

const _unionTerritory = AuthorizationTerritory(level: 'union', unionId: 1);

/// Supervisor with a territory and exactly [capabilities].
UserEntity supervisionUser({
  List<String> capabilities = const [kSupervisionAppView],
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      postRegisterComplete: true,
      onboardingMode: OnboardingMode.clubExempt,
      authorization: AuthorizationSnapshot(
        effectivePermissions: const ['clubs:read'],
        clubAssignments: const [],
        capabilities: capabilities,
        territory: _unionTerritory,
      ),
    );

class FakeSupervisionAuthNotifier extends AuthNotifier {
  FakeSupervisionAuthNotifier(this.user);

  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

/// Fails when the framework caught any exception (overflow, build error),
/// printing the full diagnostics (which widget overflowed) as the reason.
void expectNoLayoutException(WidgetTester tester) {
  var count = 0;
  while (tester.takeException() != null) {
    count++;
  }
  expect(count, 0, reason: _capturedErrors.join('\n---\n'));
}

/// Full text of every framework error of the current test (the exception
/// object alone lacks the creator chain of an overflow).
final _capturedErrors = <String>[];

/// Loads the translations and the `es` date symbols once per file.
Future<void> initSupervisionViewTests() async {
  await initCoordinatorTestLocalization();
  await initializeDateFormatting('es');
}

/// Pumps [home] inside the localized app, a minimal [GoRouter] and a
/// [testProviderScope] with the fake auth notifier plus [overrides].
Future<void> pumpSupervisionView(
  WidgetTester tester, {
  required Widget home,
  required List<Override> overrides,
  UserEntity? user,
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  } else {
    useTallSurface(tester);
  }
  _capturedErrors.clear();
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    _capturedErrors.add(details.toString());
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, __) => home)],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => FakeSupervisionAuthNotifier(user ?? supervisionUser()),
        ),
        ...overrides,
      ],
      child: localized(
        (context) => MaterialApp.router(
          routerConfig: router,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler:
                  textScale == null ? null : TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}
