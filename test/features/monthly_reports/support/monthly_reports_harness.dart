import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/domain/repositories/monthly_reports_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/riverpod_test_support.dart';

/// One-time setup shared by the monthly reports widget tests.
Future<void> setUpMonthlyReportsLocalization() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('es');
  await EasyLocalization.ensureInitialized();
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

/// Pumps [home] with the real Spanish translations and the app theme.
Future<void> pumpMonthlyReportsApp(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
            home: home,
          ),
        ),
      ),
    ),
  );
  if (settle) await settleMonthlyReports(tester);
}

/// Lets translations load and the stagger entrances finish.
Future<void> settleMonthlyReports(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Repository double: only the calls a widget test exercises are real.
class FakeMonthlyReportsRepository implements MonthlyReportsRepository {
  FakeMonthlyReportsRepository({this.saveResults = const []});

  /// Results of successive `updateManualData` calls; the last one repeats.
  /// Empty means every call succeeds.
  final List<bool> saveResults;
  final List<MonthlyReportManualData> saved = [];
  final List<String> submitted = [];

  @override
  Future<Either<Failure, MonthlyReport>> updateManualData(
    String reportId,
    MonthlyReportManualData manualData, {
    RequestCancelToken? cancelToken,
  }) async {
    final index = saved.length;
    saved.add(manualData);
    final ok = saveResults.isEmpty
        ? true
        : saveResults[
            index < saveResults.length ? index : saveResults.length - 1];
    if (!ok) return const Left(ServerFailure(message: 'boom'));
    return Right(
      MonthlyReport(
        id: reportId,
        enrollmentId: 'enrollment-1',
        month: 11,
        year: 2026,
        status: 'draft',
        manualData: manualData,
      ),
    );
  }

  @override
  Future<Either<Failure, MonthlyReport>> submitReport(
    String reportId, {
    RequestCancelToken? cancelToken,
  }) async {
    submitted.add(reportId);
    return Right(
      MonthlyReport(
        id: reportId,
        enrollmentId: 'enrollment-1',
        month: 10,
        year: 2026,
        status: 'submitted',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
