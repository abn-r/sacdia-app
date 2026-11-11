import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/enrollment/domain/entities/enrollment.dart';
import 'package:sacdia_app/features/enrollment/presentation/providers/enrollment_providers.dart';
import 'package:sacdia_app/features/finances/domain/entities/finance_export.dart';
import 'package:sacdia_app/features/finances/domain/repositories/finances_repository.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finance_export_providers.dart';
import 'package:sacdia_app/features/finances/presentation/providers/finances_providers.dart';
import 'package:sacdia_app/features/finances/presentation/widgets/finance_menu_sheet.dart';

import '../../../coordinator/coordinator_test_harness.dart';
import '../../../../support/riverpod_test_support.dart';

typedef _ExportCall = ({
  int clubId,
  int year,
  int month,
  FinanceExportFormat format
});

class _FakeRepository implements FinancesRepository {
  final calls = <_ExportCall>[];
  Completer<void>? gate;
  Either<Failure, FinanceExportFile> Function(FinanceExportFormat format)
      respond = (format) => Right(
            FinanceExportFile(
              bytes: Uint8List.fromList([37, 80, 68, 70]),
              fileName: 'finanzas-central-2026-09.${format.apiValue}',
            ),
          );

  @override
  Future<Either<Failure, FinanceExportFile>> exportFinances({
    required int clubId,
    required int year,
    required int month,
    required FinanceExportFormat format,
    RequestCancelToken? cancelToken,
  }) async {
    calls.add((clubId: clubId, year: year, month: month, format: format));
    await gate?.future;
    return respond(format);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SharedFile {
  _SharedFile(this.fileName, this.mimeType, this.bytes, this.existedWhenShared);

  final String fileName;
  final String mimeType;
  final List<int> bytes;
  final bool existedWhenShared;
}

class _FakeSharer implements FinanceExportSharer {
  final shared = <_SharedFile>[];
  File? lastFile;
  bool shouldFail = false;

  @override
  Future<void> share({
    required File file,
    required String fileName,
    required String mimeType,
    Rect? sharePositionOrigin,
  }) async {
    lastFile = file;
    shared.add(
      _SharedFile(
        fileName,
        mimeType,
        file.existsSync() ? file.readAsBytesSync() : const [],
        file.existsSync(),
      ),
    );
    if (shouldFail) throw StateError('share failed');
  }
}

class _FixedMonth extends SelectedMonthNotifier {
  @override
  SelectedMonth build() => const SelectedMonth(year: 2026, month: 9);
}

const _enrollment = Enrollment(
  id: 41,
  enrollmentUuid: 'enr-uuid-41',
  userId: 'u1',
  clubSectionId: 3,
  year: 2026,
  meetingDays: [],
  status: EnrollmentStatus.active,
);

class _Env {
  _Env(this.repo, this.sharer, this.dir, this.openedReports);

  final _FakeRepository repo;
  final _FakeSharer sharer;
  final Directory dir;
  final List<String> openedReports;
}

Future<_Env> _open(
  WidgetTester tester, {
  Enrollment? enrollment = _enrollment,
  bool enrollmentFails = false,
}) async {
  useTallSurface(tester);
  final repo = _FakeRepository();
  final sharer = _FakeSharer();
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('finance_export_test'),
  ))!;
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final opened = <String>[];

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        selectedMonthProvider.overrideWith(_FixedMonth.new),
        currentClubIdProvider.overrideWith((ref) async => 7),
        financesRepositoryProvider.overrideWithValue(repo),
        financeExportSharerProvider.overrideWithValue(sharer),
        financeExportTempDirProvider.overrideWithValue(() async => dir),
        financeExportCleanupGraceProvider.overrideWithValue(Duration.zero),
        currentEnrollmentProvider.overrideWith((ref) async {
          if (enrollmentFails) throw Exception('403');
          return enrollment;
        }),
      ],
      child: localized(
        (context) => localizedApp(
          context,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFinanceMenuSheet(
                  context,
                  onOpenReport: opened.add,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return _Env(repo, sharer, dir, opened);
}

/// Export touches real files, so alternate real time (for the IO) with pumps
/// (for the fake-async microtasks) until [done].
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('options', () {
    testWidgets('lists Excel, PDF and the monthly report', (tester) async {
      await _open(tester);

      expect(find.text('Opciones del mes'), findsOneWidget);
      expect(find.text('Exportar a Excel'), findsOneWidget);
      expect(find.text('Exportar a PDF'), findsOneWidget);
      expect(find.text('Ver informe del mes'), findsOneWidget);
    });

    testWidgets('hides the report without an enrollment id', (tester) async {
      await _open(tester, enrollment: null);

      expect(find.text('Exportar a PDF'), findsOneWidget);
      expect(find.text('Ver informe del mes'), findsNothing);
    });

    testWidgets('hides the report when the enrollment cannot be read',
        (tester) async {
      await _open(tester, enrollmentFails: true);

      expect(find.text('Ver informe del mes'), findsNothing);
    });

    testWidgets('opens the monthly reports of the active enrollment',
        (tester) async {
      final env = await _open(tester);

      await tester.tap(find.text('Ver informe del mes'));
      await tester.pumpAndSettle();

      expect(env.openedReports, ['enr-uuid-41']);
      expect(find.text('Opciones del mes'), findsNothing,
          reason: 'sheet closed');
    });
  });

  group('export', () {
    testWidgets(
        'downloads the selected month, shares the file by its server name '
        'and cleans the temp file up', (tester) async {
      final env = await _open(tester);

      await tester.tap(find.text('Exportar a PDF'));
      await tester.pump();
      await _until(tester, () => env.sharer.shared.isNotEmpty);

      expect(env.repo.calls, [
        (clubId: 7, year: 2026, month: 9, format: FinanceExportFormat.pdf),
      ]);
      final shared = env.sharer.shared.single;
      expect(shared.fileName, 'finanzas-central-2026-09.pdf');
      expect(shared.mimeType, 'application/pdf');
      expect(shared.bytes, [37, 80, 68, 70]);
      expect(shared.existedWhenShared, isTrue);
      expect(env.sharer.lastFile!.path, startsWith(env.dir.path));

      await _until(tester, () => !env.sharer.lastFile!.existsSync());
      expect(env.sharer.lastFile!.existsSync(), isFalse);
      expect(find.text('Opciones del mes'), findsNothing,
          reason: 'sheet closed');
    });

    testWidgets('Excel asks for xlsx', (tester) async {
      final env = await _open(tester);

      await tester.tap(find.text('Exportar a Excel'));
      await tester.pump();
      await _until(tester, () => env.sharer.shared.isNotEmpty);

      expect(env.repo.calls.single.format, FinanceExportFormat.xlsx);
      expect(env.sharer.shared.single.fileName, endsWith('.xlsx'));
      expect(
        env.sharer.shared.single.mimeType,
        contains('spreadsheetml.sheet'),
      );
    });

    testWidgets('shows a loader and blocks the other options while running',
        (tester) async {
      final env = await _open(tester);
      env.repo.gate = Completer<void>();
      env.repo.respond =
          (_) => const Left(ServerFailure(message: 'x', code: 500));

      await tester.tap(find.text('Exportar a PDF'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SacLoadingSmall), findsOneWidget);

      await tester.tap(find.text('Exportar a Excel'));
      await tester.pump();
      expect(env.repo.calls, hasLength(1), reason: 'second export ignored');

      env.repo.gate!.complete();
      await _until(
          tester, () => find.text('No se pudo exportar').evaluate().isNotEmpty);
    });

    testWidgets('maps a generic failure to «No se pudo exportar»',
        (tester) async {
      final env = await _open(tester);
      env.repo.respond =
          (_) => const Left(ServerFailure(message: 'boom', code: 500));

      await tester.tap(find.text('Exportar a PDF'));
      await tester.pump();
      await _until(tester, () => env.repo.calls.isNotEmpty);
      await tester.pumpAndSettle();

      expect(find.text('No se pudo exportar'), findsOneWidget);
      expect(env.sharer.shared, isEmpty);
      expect(find.text('Opciones del mes'), findsNothing);
    });

    testWidgets('maps 403 to the no-permission message', (tester) async {
      final env = await _open(tester);
      env.repo.respond =
          (_) => const Left(ServerFailure(message: 'denied', code: 403));

      await tester.tap(find.text('Exportar a Excel'));
      await tester.pump();
      await _until(tester, () => env.repo.calls.isNotEmpty);
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes permiso para exportar las finanzas'),
        findsOneWidget,
      );
      expect(env.sharer.shared, isEmpty);
    });

    testWidgets('a failing share sheet shows the error and still cleans up',
        (tester) async {
      final env = await _open(tester);
      env.sharer.shouldFail = true;

      await tester.tap(find.text('Exportar a PDF'));
      await tester.pump();
      await _until(tester, () => env.sharer.shared.isNotEmpty);
      await _until(tester, () => !env.sharer.lastFile!.existsSync());

      expect(find.text('No se pudo exportar'), findsOneWidget);
      expect(env.sharer.lastFile!.existsSync(), isFalse);
    });
  });
}
