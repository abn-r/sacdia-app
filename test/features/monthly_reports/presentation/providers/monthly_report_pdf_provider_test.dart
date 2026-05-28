import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';
import 'package:sacdia_app/features/monthly_reports/domain/repositories/monthly_reports_repository.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/providers/monthly_reports_providers.dart';

class _SlowPdfRepository implements MonthlyReportsRepository {
  final Completer<String> _downloadCompleter = Completer<String>();
  CancelToken? receivedCancelToken;

  void complete(String path) => _downloadCompleter.complete(path);

  @override
  Future<Either<Failure, String>> downloadReportPdf(
    String reportId, {
    CancelToken? cancelToken,
  }) async {
    receivedCancelToken = cancelToken;
    final path = await _downloadCompleter.future;
    return Right(path);
  }

  @override
  Future<Either<Failure, MonthlyReport>> getReportDetail(
    String reportId, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<MonthlyReport>>> getReportsByEnrollment(
    String enrollmentId, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, MonthlyReportPreview>> getPreview(
    String enrollmentId, {
    required int month,
    required int year,
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, MonthlyReport>> getOrCreateDraft(
    String enrollmentId, {
    required int month,
    required int year,
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, MonthlyReport>> updateManualData(
    String reportId,
    MonthlyReportManualData manualData, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, VisibleMonthlyReportsPage>> getVisibleReports({
    int page = 1,
    int limit = 25,
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();
}

void main() {
  test(
    'keeps the PDF download alive when it is started from an imperative read',
    () async {
      final repository = _SlowPdfRepository();
      final container = ProviderContainer(
        overrides: [
          monthlyReportsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final future =
          container.read(monthlyReportPdfProvider('report-1').future);
      await container.pump();

      expect(repository.receivedCancelToken, isNotNull);
      expect(repository.receivedCancelToken!.isCancelled, isFalse);

      repository.complete('/tmp/report.pdf');

      await expectLater(future, completion('/tmp/report.pdf'));
    },
  );
}
