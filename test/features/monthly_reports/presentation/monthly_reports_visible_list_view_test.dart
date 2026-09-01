import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/providers/monthly_reports_providers.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/views/monthly_reports_visible_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    await EasyLocalization.ensureInitialized();
  });

  testWidgets(
    'should show translated copy without overflow on a narrow phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnrollmentProvider.overrideWith(
              (ref) async => const Enrollment(
                id: 1,
                userId: 'user-1',
                clubSectionId: 1,
                year: 2026,
                meetingDays: [],
                status: EnrollmentStatus.active,
              ),
            ),
            visibleMonthlyReportsProvider.overrideWith(
              (ref) async => VisibleMonthlyReportsPage(
                total: 1,
                page: 1,
                limit: 20,
                items: [
                  VisibleMonthlyReport(
                    id: 'report-1',
                    enrollmentId: 'enrollment-1',
                    month: now.month,
                    year: now.year,
                    status: 'draft',
                    clubName: 'ACV',
                    clubType: 'Conquistadores',
                  ),
                ],
              ),
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
                home: const MonthlyReportsVisibleListView(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(tester.takeException(), isNull);
      expect(find.text('Reportes'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Borrador en curso'), findsOneWidget);
      expect(
        find.textContaining('monthly_reports.visible'),
        findsNothing,
      );
    },
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
