import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/views/panel_only_account_view.dart';

import '../../../family/family_test_harness.dart';

const _hint = ValueKey('panel_only_check_hint');
const _unchanged = ValueKey('panel_only_unchanged');
const _family = ValueKey('panel_only_family');
const _familyHint = ValueKey('panel_only_family_hint');
const _check = ValueKey('panel_only_check');
const _signOut = ValueKey('panel_only_sign_out');

UserEntity _user({FamilySummary? family}) => UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      onboardingMode: OnboardingMode.panelOnly,
      family: family,
    );

class _Auth extends AuthNotifier {
  _Auth(this.user);

  final UserEntity user;
  int signOuts = 0;
  int refreshes = 0;
  Duration? lastMinInterval;
  Completer<bool> refreshResult = Completer<bool>();

  @override
  Future<UserEntity?> build() async => user;

  @override
  Future<bool> refreshAuthorization({
    Duration minInterval = const Duration(seconds: 30),
  }) {
    refreshes++;
    lastMinInterval = minInterval;
    return refreshResult.future;
  }

  @override
  Future<bool> signOut() async {
    signOuts++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<({_Auth auth, dynamic router})> mount(
    WidgetTester tester,
    UserEntity user,
  ) async {
    final auth = _Auth(user);
    final router = await pumpFamilyApp(
      tester,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const PanelOnlyAccountView()),
        stubRoute(RouteNames.family),
      ],
      overrides: [authNotifierProvider.overrideWith(() => auth)],
    );
    await tester.pumpAndSettle();
    return (auth: auth, router: router);
  }

  group('a non-guardian account', () {
    testWidgets('shows no family action, only check again and sign out',
        (tester) async {
      await mount(tester, _user());

      expect(find.byKey(_family), findsNothing);
      expect(find.byKey(_familyHint), findsNothing);
      expect(find.byKey(_check), findsOneWidget);
      expect(find.byKey(_hint), findsOneWidget);
      expect(find.byKey(_signOut), findsOneWidget);
    });

    testWidgets('a family snapshot without guardianship adds no action',
        (tester) async {
      await mount(
        tester,
        _user(
          family: const FamilySummary(isGuardian: false, dependentsCount: 0),
        ),
      );

      expect(find.byKey(_family), findsNothing);
    });
  });

  group('a guardian account', () {
    testWidgets('shows Mi familia and its hint, and pushes /family',
        (tester) async {
      final h = await mount(
        tester,
        _user(
          family: const FamilySummary(isGuardian: true, dependentsCount: 1),
        ),
      );

      expect(find.byKey(_familyHint), findsOneWidget);
      await tester.tap(find.byKey(_family));
      await tester.pumpAndSettle();

      expect(find.text('route:${RouteNames.family}'), findsOneWidget);
      // Es un push: la pantalla de solo panel sigue debajo.
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(PanelOnlyAccountView), findsOneWidget);
    });

    testWidgets('a guardian by dependents_count alone also sees it',
        (tester) async {
      await mount(
        tester,
        _user(
          family: const FamilySummary(isGuardian: false, dependentsCount: 2),
        ),
      );

      expect(find.byKey(_family), findsOneWidget);
    });
  });

  group('check again', () {
    testWidgets(
        'forces a fresh read, shows loading, then the unchanged text '
        'replaces the hint', (tester) async {
      final h = await mount(tester, _user());

      await tester.tap(find.byKey(_check));
      await tester.pump();

      expect(h.auth.refreshes, 1);
      expect(h.auth.lastMinInterval, Duration.zero);
      // Cargando: el botón no acepta otro toque y la ayuda sigue ahí.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.tap(find.byKey(_check), warnIfMissed: false);
      await tester.pump();
      expect(h.auth.refreshes, 1);
      expect(find.byKey(_hint), findsOneWidget);
      expect(find.byKey(_unchanged), findsNothing);

      h.auth.refreshResult.complete(false);
      await tester.pumpAndSettle();

      expect(find.byKey(_unchanged), findsOneWidget);
      expect(find.byKey(_hint), findsNothing);
    });

    testWidgets('a changed mode leaves no "unchanged" text', (tester) async {
      final h = await mount(tester, _user());

      await tester.tap(find.byKey(_check));
      await tester.pump();
      h.auth.refreshResult.complete(true);
      await tester.pumpAndSettle();

      expect(find.byKey(_unchanged), findsNothing);
      expect(find.byKey(_hint), findsOneWidget);
    });

    testWidgets('a failed read counts as unchanged', (tester) async {
      final h = await mount(tester, _user());

      await tester.tap(find.byKey(_check));
      await tester.pump();
      h.auth.refreshResult.completeError(StateError('offline'));
      await tester.pumpAndSettle();

      expect(find.byKey(_unchanged), findsOneWidget);
    });

    testWidgets('a second check clears the previous result', (tester) async {
      final h = await mount(tester, _user());

      await tester.tap(find.byKey(_check));
      await tester.pump();
      h.auth.refreshResult.complete(false);
      await tester.pumpAndSettle();
      expect(find.byKey(_unchanged), findsOneWidget);

      h.auth.refreshResult = Completer<bool>();
      await tester.tap(find.byKey(_check));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_unchanged), findsNothing);
      expect(h.auth.refreshes, 2);
    });
  });

  testWidgets('sign out calls the notifier', (tester) async {
    final h = await mount(tester, _user());

    await tester.tap(find.byKey(_signOut));
    await tester.pump();

    expect(h.auth.signOuts, 1);
  });

  testWidgets('back is blocked', (tester) async {
    await mount(tester, _user());

    final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
    expect(popScope.canPop, isFalse);
  });
}
