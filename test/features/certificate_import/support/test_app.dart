import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// ignore: unnecessary_import
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/riverpod_test_support.dart';

/// Reads the real translation files, so tests assert the shipped Spanish copy.
class FileAssetLoader extends AssetLoader {
  const FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      jsonDecode(
              File('$path/${locale.toLanguageTag()}.json').readAsStringSync())
          as Map<String, dynamic>;
}

/// Call once from `setUpAll`.
Future<void> initTestLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

/// [child] in a Spanish app. With [proofRoutes] the app has a router whose
/// proof route prints `PROOF <fileId> p<page>`, so tests can assert where a
/// "see in your proof" button navigates. [overrides] feed Riverpod.
Widget wrapTestApp(
  Widget child, {
  bool proofRoutes = false,
  List<Override> overrides = const [],
}) {
  return testProviderScope(
    overrides: overrides,
    child: _localized(child, proofRoutes),
  );
}

Widget _localized(Widget child, bool proofRoutes) {
  return EasyLocalization(
    supportedLocales: const [Locale('es')],
    path: 'assets/translations',
    assetLoader: const FileAssetLoader(),
    fallbackLocale: const Locale('es'),
    startLocale: const Locale('es'),
    child: Builder(builder: (context) {
      if (!proofRoutes) {
        return MaterialApp(
          theme: AppTheme.lightTheme,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          home: child,
        );
      }
      return MaterialApp.router(
        theme: AppTheme.lightTheme,
        locale: context.locale,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => child),
          GoRoute(
            path: '/certificate-import/:batchId/proof/:fileId',
            builder: (_, state) => Scaffold(
              body: Text('PROOF ${state.pathParameters['fileId']} '
                  'p${state.uri.queryParameters['page'] ?? '1'}'),
            ),
          ),
        ]),
      );
    }),
  );
}

/// Tall surface for several rows. Wider than a phone on purpose: the test
/// font (Ahem) draws every glyph as wide as it is tall, so real copy needs
/// more room than it does on a device.
void phoneSurface(WidgetTester tester, {double height = 1600}) {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Turns on the system "reduce motion" flag for the test.
void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
