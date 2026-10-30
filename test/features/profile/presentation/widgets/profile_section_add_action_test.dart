import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: unnecessary_import
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/profile_certifications_section.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/profile_classes_section.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/profile_quiet_add_chip.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/profile_section_header_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/riverpod_test_support.dart';

/// The profile header and the section's empty state must never both offer
/// "Agregar": exactly one add action in every state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(
    WidgetTester tester, {
    required List<Override> overrides,
    required Widget header,
    required Widget section,
  }) async {
    await tester.pumpWidget(
      testProviderScope(
        overrides: overrides,
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
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(children: [header, section]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('Clases add action', () {
    final header = ProfileClassesHeaderActions(onRefresh: () {});
    const section = ProfileClassesSection();

    testWidgets('shows a single Agregar when there are no classes',
        (tester) async {
      await pump(
        tester,
        overrides: [
          userClassesProvider.overrideWith((ref) async => const []),
        ],
        header: header,
        section: section,
      );

      expect(find.byType(ProfileQuietAddChip), findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);
      // The one left is the empty-state chip, not the header one.
      expect(
        find.descendant(
          of: find.byType(ProfileClassesSection),
          matching: find.byType(ProfileQuietAddChip),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a single Agregar in the header when there are classes',
        (tester) async {
      await pump(
        tester,
        overrides: [
          userClassesProvider.overrideWith(
            (ref) async => const [
              ProgressiveClass(id: 1, name: 'Amigo', clubTypeId: 2),
            ],
          ),
        ],
        header: header,
        section: section,
      );

      expect(find.byType(ProfileQuietAddChip), findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileClassesHeaderActions),
          matching: find.byType(ProfileQuietAddChip),
        ),
        findsOneWidget,
      );
    });
  });

  group('Certificaciones add action', () {
    final header = ProfileCertificationsHeaderActions(onRefresh: () {});
    const section = ProfileCertificationsSection();

    testWidgets('shows a single Agregar when there are no certifications',
        (tester) async {
      await pump(
        tester,
        overrides: [
          userCertificationsProvider.overrideWith((ref) async => const []),
        ],
        header: header,
        section: section,
      );

      expect(find.byType(ProfileQuietAddChip), findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileCertificationsSection),
          matching: find.byType(ProfileQuietAddChip),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'shows a single Agregar in the header when there are certifications',
        (tester) async {
      await pump(
        tester,
        overrides: [
          userCertificationsProvider.overrideWith(
            (ref) async => [
              UserCertification(
                enrollmentId: 1,
                certificationId: 1,
                certificationName: 'Guía Mayor Avanzado',
                enrollmentDate: DateTime(2026, 6, 11),
                completionStatus: 'IN_PROGRESS',
                progressPercentage: 40,
                modulesCompleted: 2,
                modulesTotal: 5,
                active: true,
              ),
            ],
          ),
        ],
        header: header,
        section: section,
      );

      expect(find.byType(ProfileQuietAddChip), findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileCertificationsHeaderActions),
          matching: find.byType(ProfileQuietAddChip),
        ),
        findsOneWidget,
      );
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
