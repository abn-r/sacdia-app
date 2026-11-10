import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/presentation/views/welcome_carousel_view.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/riverpod_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('first page shows brand copy and skip goes to login',
      (tester) async {
    await _phone(tester);
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs);

    expect(find.textContaining('Tu club,', findRichText: true), findsOneWidget);
    expect(find.text('en tu bolsillo'), findsOneWidget);
    expect(find.byKey(const Key('welcome-skip')), findsOneWidget);
    // Back keeps its space on page 1 but is not visible.
    expect(find.byKey(const Key('welcome-back')).hitTestable(), findsNothing);

    await tester.tap(find.byKey(const Key('welcome-skip')));
    await _advance(tester);

    expect(find.text('login-dest'), findsOneWidget);
    expect(prefs.getBool(AppConstants.welcomeCarouselSeenKey), isTrue);
  });

  testWidgets('six pages, last offers create account and sign in',
      (tester) async {
    await _phone(tester);
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs, reduceMotion: true);

    for (var i = 0; i < 6; i++) {
      expect(find.byKey(Key('welcome-progress-$i')), findsOneWidget);
    }
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(const Key('welcome-next')), findsOneWidget);
      await tester.tap(find.byKey(const Key('welcome-next')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('welcome-next')), findsNothing);
    expect(find.byKey(const Key('welcome-create-account')), findsOneWidget);
    expect(find.byKey(const Key('welcome-sign-in')), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Ya tengo cuenta'), findsOneWidget);
    expect(find.byKey(const Key('welcome-back')), findsOneWidget);
  });

  testWidgets('create account goes to register and marks seen', (tester) async {
    await _phone(tester);
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs, reduceMotion: true);

    await tester.tap(find.byKey(const Key('welcome-progress-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-create-account')));
    await tester.pumpAndSettle();

    expect(find.text('register-dest'), findsOneWidget);
    expect(prefs.getBool(AppConstants.welcomeCarouselSeenKey), isTrue);

    // Back from register lands on login (register is opened on top of it).
    await tester.tap(find.text('register-dest'));
    await tester.pumpAndSettle();
    expect(find.text('login-dest'), findsOneWidget);
  });

  testWidgets('I already have an account goes to login and marks seen',
      (tester) async {
    await _phone(tester);
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs, reduceMotion: true);

    await tester.tap(find.byKey(const Key('welcome-progress-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-sign-in')));
    await tester.pumpAndSettle();

    expect(find.text('login-dest'), findsOneWidget);
    expect(prefs.getBool(AppConstants.welcomeCarouselSeenKey), isTrue);
  });

  testWidgets('animated pages keep running without throwing', (tester) async {
    await _phone(tester);
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs);

    for (var page = 0; page < 6; page++) {
      if (page > 0) {
        await tester.tap(find.byKey(Key('welcome-progress-$page')));
        await _advance(tester);
      }
      // Walk well past the intro of each scene (scene 2 needs ~10s).
      for (var s = 0; s < 14; s++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders without pending timers', (tester) async {
    await _phone(tester);
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs, reduceMotion: true);

    // Would hang if any scene kept a ticker alive.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme pumps every page without exceptions', (tester) async {
    await _phone(tester);
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs, dark: true);

    for (var page = 1; page < 6; page++) {
      await tester.tap(find.byKey(Key('welcome-progress-$page')));
      await _advance(tester);
      await tester.pump(const Duration(seconds: 3));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone with large text does not overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs, textScale: 1.6);
    for (var page = 1; page < 6; page++) {
      await tester.tap(find.byKey(Key('welcome-progress-$page')));
      await _advance(tester);
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets a page change and a route transition play out. `pumpAndSettle` would
/// wait forever on the looping scenes, so step the clock by hand.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpCarousel(
  WidgetTester tester,
  SharedPreferences prefs, {
  bool reduceMotion = false,
  bool dark = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    _wrap(
      prefs,
      const WelcomeCarouselView(),
      reduceMotion: reduceMotion,
      dark: dark,
      textScale: textScale,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Widget _wrap(
  SharedPreferences prefs,
  Widget home, {
  bool reduceMotion = false,
  bool dark = false,
  double textScale = 1,
}) {
  final router = GoRouter(
    initialLocation: RouteNames.welcome,
    routes: [
      GoRoute(
        path: RouteNames.welcome,
        builder: (_, __) => home,
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const Text('login-dest'),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, __) => TextButton(
          onPressed: () => context.pop(),
          child: const Text('register-dest'),
        ),
      ),
    ],
  );

  return testProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: EasyLocalization(
      supportedLocales: const [Locale('es')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('es'),
      startLocale: const Locale('es'),
      child: Builder(
        builder: (context) => MaterialApp.router(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          locale: context.locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          routerConfig: router,
        ),
      ),
    ),
  );
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
