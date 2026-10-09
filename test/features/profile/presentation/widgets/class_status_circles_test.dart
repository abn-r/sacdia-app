import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/class_status_circles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('ClassStatusCircles', () {
    testWidgets('should hide class names until a badge is tapped',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userClassesProvider.overrideWith((ref) async => const []),
            allClassesProvider.overrideWith(
              (ref) async => const [
                ProgressiveClass(
                  id: 1,
                  name: 'Corderitos',
                  clubTypeId: 1,
                  assetCode: 'AV-01',
                  minimumAge: 6,
                  description: 'Primera clase de Aventureros',
                ),
              ],
            ),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            path: 'assets/translations',
            assetLoader: const _FileAssetLoader(),
            fallbackLocale: const Locale('es'),
            startLocale: const Locale('es'),
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.lightTheme,
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const Scaffold(
                  body: ClassStatusCircles(clubType: 'Aventureros'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Corderitos'), findsNothing);
      expect(find.text('Aves Madrugadoras'), findsNothing);

      await tester.tap(find.byType(SacPressable).first);
      await tester.pumpAndSettle();

      expect(find.text('Corderitos'), findsOneWidget);
      expect(find.text('No inscrita'), findsOneWidget);
      expect(find.text('Desde 6 años'), findsOneWidget);
      expect(find.text('Primera clase de Aventureros'), findsOneWidget);
    });
  });
  group('ClassStatusCircles investiture state', () {
    Future<void> pumpCircles(
      WidgetTester tester, {
      required String investitureStatus,
      required int progress,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userClassesProvider.overrideWith(
              (ref) async => [
                ProgressiveClass(
                  id: 1,
                  name: 'Amigo',
                  clubTypeId: 2,
                  assetCode: 'CQ-01',
                  enrollmentId: 7,
                  investitureStatus: investitureStatus,
                  overallProgress: progress,
                ),
              ],
            ),
            allClassesProvider.overrideWith((ref) async => const []),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            path: 'assets/translations',
            assetLoader: const _FileAssetLoader(),
            fallbackLocale: const Locale('es'),
            startLocale: const Locale('es'),
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.lightTheme,
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const Scaffold(
                  body: ClassStatusCircles(clubType: 'Conquistadores'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a class with high progress is not drawn as invested',
        (tester) async {
      await pumpCircles(
        tester,
        investitureStatus: 'IN_PROGRESS',
        progress: 95,
      );

      // En curso: lleva la insignia de avance y el logo atenuado.
      expect(find.text('95%'), findsOneWidget);
    });

    testWidgets('only the INVESTIDO status draws the class as invested',
        (tester) async {
      await pumpCircles(
        tester,
        investitureStatus: 'INVESTIDO',
        progress: 95,
      );

      // Investida: sin insignia de avance.
      expect(find.text('95%'), findsNothing);
    });
  });
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
