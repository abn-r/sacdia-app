import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/presentation/views/welcome_carousel_view.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('first slide shows brand copy and skip goes to login',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs);

    expect(find.text('Los clubes de tu iglesia,'), findsOneWidget);
    expect(find.text('en un sistema'), findsOneWidget);
    expect(find.byKey(const Key('welcome-skip')), findsOneWidget);
    expect(find.byKey(const Key('welcome-back')), findsNothing);

    await tester.tap(find.byKey(const Key('welcome-skip')));
    await tester.pumpAndSettle();

    expect(find.text('login-dest'), findsOneWidget);
    expect(prefs.getBool(AppConstants.welcomeCarouselSeenKey), isTrue);
  });

  testWidgets('next reaches last slide then continue goes to login',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await _pumpCarousel(tester, prefs);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    expect(
      find.text('El avance de tu clase, de principio a fin'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    expect(
      find.text('Tus especialidades, como la banda'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('welcome-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    expect(
      find.text('Tú diriges. El club queda en orden'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pumpAndSettle();
    expect(find.text('Tu trayectoria de servicio'), findsOneWidget);
    expect(find.byKey(const Key('welcome-continue')), findsOneWidget);
    expect(find.byKey(const Key('welcome-sign-in')), findsNothing);
    expect(find.byKey(const Key('welcome-create-account')), findsNothing);

    await tester.tap(find.byKey(const Key('welcome-continue')));
    await tester.pumpAndSettle();

    expect(find.text('login-dest'), findsOneWidget);
    expect(prefs.getBool(AppConstants.welcomeCarouselSeenKey), isTrue);
  });

  testWidgets('reduced motion still shows titles via next', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _wrap(
        prefs,
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: WelcomeCarouselView(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Los clubes de tu iglesia,'), findsOneWidget);
    expect(find.text('en un sistema'), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-next')));
    await tester.pump();
    expect(
      find.text('El avance de tu clase, de principio a fin'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpCarousel(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(_wrap(prefs, const WelcomeCarouselView()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

Widget _wrap(SharedPreferences prefs, Widget home) {
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
        builder: (_, __) => const Text('register-dest'),
      ),
    ],
  );

  return ProviderScope(
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
          theme: AppTheme.lightTheme,
          locale: context.locale,
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
