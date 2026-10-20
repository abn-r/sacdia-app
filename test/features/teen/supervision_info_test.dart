import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/family/presentation/widgets/family_prompt_host.dart';
import 'package:sacdia_app/features/teen/presentation/widgets/supervision_info_card.dart';
import 'package:sacdia_app/features/teen/presentation/widgets/supervision_info_notice_host.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../family/family_test_harness.dart';

UserEntity _user(AccountMode mode, {String id = 'teen-1'}) =>
    UserEntity(id: id, postRegisterComplete: true, serverMode: mode);

class _MutableAuth extends AuthNotifier {
  _MutableAuth(this.initial);

  final UserEntity? initial;

  @override
  Future<UserEntity?> build() async => initial;

  void emit(UserEntity? user) => state = AsyncValue.data(user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  const note = 'Tu tutor puede ver tu progreso y tu asistencia. No puede ver '
      'tu información de salud ni tus mensajes.';

  group('shouldShowSupervisionInfo', () {
    bool should(
      UserEntity? previous,
      UserEntity? next, {
      bool acting = false,
      bool seen = false,
    }) =>
        shouldShowSupervisionInfo(
          previous,
          next,
          acting: acting,
          alreadySeen: seen,
        );

    test('on the first supervised state of a session', () {
      expect(should(null, _user(AccountMode.teenSupervised)), isTrue);
    });

    test('when a pending teen gets a verified guardian', () {
      expect(
        should(
          _user(AccountMode.teenPending),
          _user(AccountMode.teenSupervised),
        ),
        isTrue,
      );
    });

    test('not on refreshes inside the same mode', () {
      expect(
        should(
          _user(AccountMode.teenSupervised),
          _user(AccountMode.teenSupervised),
        ),
        isFalse,
      );
    });

    test('never for adults, pending teens, acting or once seen', () {
      expect(should(null, _user(AccountMode.adult)), isFalse);
      expect(should(null, _user(AccountMode.teenPending)), isFalse);
      expect(should(null, null), isFalse);
      expect(
        should(null, _user(AccountMode.teenSupervised), acting: true),
        isFalse,
      );
      expect(
        should(null, _user(AccountMode.teenSupervised), seen: true),
        isFalse,
      );
    });
  });

  group('SupervisionInfoCard in the profile', () {
    Future<void> pump(WidgetTester tester, UserEntity user) async {
      await pumpFamilyApp(
        tester,
        overrides: [
          authNotifierProvider.overrideWith(() => _MutableAuth(user)),
        ],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SupervisionInfoSlot(horizontalPadding: 16),
            ),
          ),
        ],
      );
      await tester.pump();
    }

    testWidgets(
        'a teen with a verified guardian sees what is and is not shared',
        (tester) async {
      await pump(tester, _user(AccountMode.teenSupervised));

      expect(
          find.byKey(const ValueKey('supervision_info_card')), findsOneWidget);
      expect(find.text('Tu tutor y tu información'), findsOneWidget);
      expect(find.text(note), findsOneWidget);
    });

    testWidgets('adults and pending teens do not get the card', (tester) async {
      await pump(tester, _user(AccountMode.adult));
      expect(find.byKey(const ValueKey('supervision_info_card')), findsNothing);

      await pump(tester, _user(AccountMode.teenPending));
      expect(find.byKey(const ValueKey('supervision_info_card')), findsNothing);
    });
  });

  group('SupervisionInfoNoticeHost', () {
    final navigatorKey = GlobalKey<NavigatorState>();

    Future<({_MutableAuth auth, SharedPreferences prefs})> pump(
      WidgetTester tester,
      UserEntity? initial, {
      Map<String, Object> prefsValues = const {},
      ActingForSession? session,
    }) async {
      SharedPreferences.setMockInitialValues(prefsValues);
      final prefs = await SharedPreferences.getInstance();
      final auth = _MutableAuth(initial);
      // El host va en el `builder` del MaterialApp, como en main.dart.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => auth),
            sharedPreferencesProvider.overrideWithValue(prefs),
            if (session != null)
              actingForSessionProvider.overrideWithValue(session),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            path: 'assets/translations',
            assetLoader: const FileAssetLoader(),
            fallbackLocale: const Locale('es'),
            startLocale: const Locale('es'),
            child: Builder(
              builder: (context) => MaterialApp(
                navigatorKey: navigatorKey,
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const Scaffold(body: Text('home')),
                builder: (context, child) => SupervisionInfoNoticeHost(
                  navigatorKey: navigatorKey,
                  delay: Duration.zero,
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return (auth: auth, prefs: prefs);
    }

    testWidgets('shows the note once when the guardian is verified',
        (tester) async {
      final h = await pump(tester, _user(AccountMode.teenPending));
      expect(find.text('Entendido'), findsNothing);

      h.auth.emit(_user(AccountMode.teenSupervised));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Entendido'), findsOneWidget);
      expect(h.prefs.getBool(kSupervisionInfoSeenPrefsKey), isTrue);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Entendido'), findsNothing);

      // Otro refresco del mismo modo: no vuelve a salir.
      h.auth.emit(_user(AccountMode.teenSupervised));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Entendido'), findsNothing);
    });

    testWidgets('does not show it if it was already seen', (tester) async {
      final h = await pump(
        tester,
        _user(AccountMode.teenPending),
        prefsValues: {kSupervisionInfoSeenPrefsKey: true},
      );

      h.auth.emit(_user(AccountMode.teenSupervised));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Entendido'), findsNothing);
    });

    testWidgets('never for an adult', (tester) async {
      final h = await pump(tester, null);

      h.auth.emit(_user(AccountMode.adult, id: 'adult-1'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Entendido'), findsNothing);
      expect(h.prefs.getBool(kSupervisionInfoSeenPrefsKey), isNull);
    });
  });

  test('the family prompt never asks a supervised teen about dependents', () {
    expect(
      shouldPromptFamily(
        const UserEntity(id: 'teen-1', postRegisterComplete: false),
        const UserEntity(
          id: 'teen-1',
          postRegisterComplete: true,
          serverMode: AccountMode.teenPending,
        ),
        acting: false,
      ),
      isFalse,
    );
    expect(
      shouldPromptFamily(
        const UserEntity(id: 'adult-1', postRegisterComplete: false),
        const UserEntity(id: 'adult-1', postRegisterComplete: true),
        acting: false,
      ),
      isTrue,
    );
  });
}
