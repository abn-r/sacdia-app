/// Widget tests for the territorial monthly-reports view: month header and
/// selector, compliance by club, the reports of the month and their PDF.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart' show HugeIconData;
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_report.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_reports_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_reports_view.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_summary_box.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';

import 'supervision_reports_progress_test_harness.dart';
import 'supervision_view_test_harness.dart';

const _narrow = Size(320, 640);

/// Short enough for a drag to pass the RefreshIndicator trigger (25% of it).
const _short = Size(800, 900);
const _longName =
    'Club de Conquistadores Estrella de la Mañana de la Asociación Central '
    'del Valle Grande';

Future<FakeReportsRepo> _pump(
  WidgetTester tester, {
  FakeReportsRepo? repo,
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeReportsRepo();
  await pumpSupervisionView(
    tester,
    home: const SupervisionReportsView(),
    overrides: [supervisionReportsRepositoryProvider.overrideWithValue(fake)],
    size: size,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}

/// Repo with [started] periods and a compliance page whose totals are the
/// counts of the requested month.
FakeReportsRepo _repoWith(
  List<SupervisionReportPeriod> started, {
  List<SupervisionClubCompliance>? clubs,
}) {
  final repo = FakeReportsRepo()
    ..onPeriods = () async => Right(periods(started));
  repo.onCompliance = (call) async {
    final match = started.firstWhere((p) => p.key == call.period);
    return Right(
      compliancePage(
        clubs ?? [clubCompliance(1)],
        totals: match.counts,
      ),
    );
  };
  return repo;
}

/// A segment of the «Por club | Informes» control (label plus its count).
Finder _tab(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is SupervisionSegmentedControl),
      matching: find.textContaining(label),
    );

Finder _row(String title) => find.widgetWithText(SacListRow, title);

Finder _icon(HugeIconData icon) =>
    find.byWidgetPredicate((w) => w is HugeIcon && w.icon == icon);

Finder _sheet() => find.byType(BottomSheet);

/// Scrolls the main list until [target] is built and on screen.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  // scrollUntilVisible stops at the edge: bring it clear of the frosted bar.
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 140));
  await tester.pumpAndSettle();
}

/// Flings the main list down past the trigger distance of the
/// RefreshIndicator and lets the refresh finish.
Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.flingFrom(const Offset(400, 300), const Offset(0, 600), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

String _dayMonth(DateTime d) => DateFormat.MMMd('es').format(d);

void main() {
  setUpAll(initSupervisionViewTests);

  group('month header', () {
    testWidgets('shows the skeleton while the periods load, then the month', (
      tester,
    ) async {
      final gate = Completer<SupervisionReportPeriods>();
      final repo = FakeReportsRepo();
      repo.onPeriods = () async => Right(await gate.future);
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.text('Octubre de 2026'), findsNothing);

      gate.complete(periods([period(2026, 10, counts: counts(expected: 3))]));
      await tester.pumpAndSettle();

      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Octubre de 2026'), findsOneWidget);
    });

    testWidgets('shows the capitalized month and year of the default period', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([period(2026, 10, counts: counts(expected: 3))]),
      );

      expect(find.text('Octubre de 2026'), findsOneWidget);
      expect(find.text('octubre de 2026'), findsNothing);
      expect(find.text('Informes mensuales'), findsOneWidget);
    });

    testWidgets('the month sits in the top bar and the box below it', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([
          period(2026, 10, counts: counts(expected: 3, submitted: 1)),
        ]),
      );

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Octubre de 2026'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SupervisionSummaryBox), findsOneWidget);
      expect(find.text('Entregados'), findsOneWidget);
    });

    testWidgets('default period skips newer months with nothing expected', (
      tester,
    ) async {
      final repo = _repoWith([
        period(2026, 11),
        period(2026, 10, counts: counts(expected: 3, submitted: 1)),
        period(2026, 9, counts: counts(expected: 3, submitted: 3)),
      ]);
      await _pump(tester, repo: repo);

      expect(find.text('Octubre de 2026'), findsOneWidget);
      expect(find.text('Noviembre de 2026'), findsNothing);
      expect(repo.complianceCalls.single.period, (year: 2026, month: 10));
    });

    testWidgets('falls back to the newest month when none expects reports', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([period(2026, 11), period(2026, 10)]),
      );

      expect(find.text('Noviembre de 2026'), findsOneWidget);
    });

    testWidgets('the box shows delivered of expected, percent and legend', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([
          period(
            2026,
            10,
            counts: counts(expected: 5, submitted: 2, pending: 2, overdue: 1),
          ),
        ]),
      );

      expect(find.textContaining('2 de 5'), findsOneWidget);
      expect(find.textContaining('40%'), findsOneWidget);
      expect(find.textContaining('Entregados 2'), findsOneWidget);
      expect(find.textContaining('Pendientes 2'), findsOneWidget);
      expect(find.textContaining('Vencidos 1'), findsOneWidget);
    });

    testWidgets('the legend leaves out the zero parts', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([
          period(2026, 10, counts: counts(expected: 5, submitted: 5)),
        ]),
      );

      expect(find.textContaining('5 de 5'), findsOneWidget);
      expect(find.textContaining('Entregados 5'), findsOneWidget);
      expect(find.textContaining('Vencidos '), findsNothing);
      expect(find.textContaining('Pendientes '), findsNothing);
    });

    testWidgets('shows only the overdue part when nothing is pending', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([
          period(2026, 10,
              counts: counts(expected: 5, submitted: 4, overdue: 1)),
        ]),
      );

      expect(find.textContaining('4 de 5'), findsOneWidget);
      expect(find.textContaining('Vencidos 1'), findsOneWidget);
      expect(find.textContaining('Pendientes '), findsNothing);
    });

    testWidgets('says nothing was expected when the expected count is 0', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([period(2026, 10)], clubs: const []),
      );

      expect(find.textContaining('Sin informes esperados'), findsOneWidget);
      // Only the box label: no legend.
      expect(find.textContaining('Entregados '), findsNothing);
    });

    testWidgets('formats big counts with grouping', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([
          period(2026, 10, counts: counts(expected: 1234567, submitted: 1000)),
        ]),
      );

      // Spanish groups thousands the Mexican way.
      expect(find.textContaining('1,000 de 1,234,567'), findsOneWidget);
    });

    testWidgets('shows the deadline as «límite» in the box when it has one', (
      tester,
    ) async {
      final due = DateTime(2026, 10, 31);
      await _pump(
        tester,
        repo: _repoWith([
          period(2026, 10, dueAt: due, counts: counts(expected: 3)),
        ]),
      );

      expect(find.text('límite ${_dayMonth(due)}'), findsOneWidget);
    });

    testWidgets('omits the deadline when the period has none', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([period(2026, 10, counts: counts(expected: 3))]),
      );

      expect(find.textContaining('límite'), findsNothing);
    });

    testWidgets('header uses the totals of the compliance page once loaded', (
      tester,
    ) async {
      final repo = FakeReportsRepo()
        ..onPeriods = (() async => Right(
              periods([period(2026, 10, counts: counts(expected: 3))]),
            ))
        ..onCompliance = (_) async => Right(
              compliancePage(
                [clubCompliance(1)],
                totals: counts(expected: 4, submitted: 4),
              ),
            );
      await _pump(tester, repo: repo);

      expect(find.textContaining('4 de 4'), findsOneWidget);
    });
  });

  group('month selector', () {
    testWidgets('with one started period the month is not a button', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([period(2026, 10, counts: counts(expected: 3))]),
      );

      await tester.tap(find.text('Octubre de 2026'));
      await tester.pumpAndSettle();

      expect(find.text('Elige un mes'), findsNothing);
      expect(_icon(HugeIcons.strokeRoundedArrowDown01), findsNothing);
    });

    testWidgets('with several periods the month opens the sheet, newest first',
        (tester) async {
      await _pump(
        tester,
        repo: _repoWith([
          period(2026, 10, counts: counts(expected: 3, submitted: 2)),
          period(2026, 9, counts: counts(expected: 4, submitted: 4)),
          period(2026, 8,
              counts: counts(expected: 2, submitted: 1, overdue: 1)),
        ]),
      );
      expect(_icon(HugeIcons.strokeRoundedArrowDown01), findsOneWidget);

      await tester.tap(find.text('Octubre de 2026'));
      await tester.pumpAndSettle();

      expect(find.text('Elige un mes'), findsOneWidget);
      Finder inSheet(String text) =>
          find.descendant(of: _sheet(), matching: find.text(text));
      final oct = tester.getTopLeft(inSheet('Octubre de 2026')).dy;
      final sep = tester.getTopLeft(inSheet('Septiembre de 2026')).dy;
      final aug = tester.getTopLeft(inSheet('Agosto de 2026')).dy;
      expect(oct, lessThan(sep));
      expect(sep, lessThan(aug));
      // Each month carries its own compliance line.
      expect(inSheet('4 de 4 entregados'), findsOneWidget);
      expect(inSheet('1 de 2 entregados · Vencidos: 1'), findsOneWidget);
      // The year of the periods under the title.
      expect(inSheet('Año eclesiástico 2026'), findsOneWidget);
    });

    testWidgets('the sheet checks only the current month', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([
          period(2026, 10, counts: counts(expected: 3)),
          period(2026, 9, counts: counts(expected: 4)),
        ]),
      );
      await tester.tap(find.text('Octubre de 2026'));
      await tester.pumpAndSettle();

      final tick = find.descendant(
        of: _sheet(),
        matching: _icon(HugeIcons.strokeRoundedTick02),
      );
      expect(tick, findsOneWidget);
      final octRow = tester.getCenter(
        find.descendant(
          of: _sheet(),
          matching: find.text('Octubre de 2026'),
        ),
      );
      expect((tester.getCenter(tick).dy - octRow.dy).abs(), lessThan(30));
    });

    testWidgets('picking another month reloads compliance and the header', (
      tester,
    ) async {
      final repo = _repoWith([
        period(2026, 10, counts: counts(expected: 3, submitted: 2)),
        period(2026, 9, counts: counts(expected: 4, submitted: 4)),
      ]);
      await _pump(tester, repo: repo);
      expect(repo.complianceCalls.map((c) => c.period), [
        (year: 2026, month: 10),
      ]);

      await tester.tap(find.text('Octubre de 2026'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _sheet(),
          matching: find.text('Septiembre de 2026'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Elige un mes'), findsNothing);
      expect(find.text('Septiembre de 2026'), findsOneWidget);
      expect(find.text('Octubre de 2026'), findsNothing);
      expect(find.textContaining('4 de 4'), findsOneWidget);
      expect(repo.complianceCalls.last.period, (year: 2026, month: 9));
      expect(repo.complianceCalls.last.page, 1);
    });

    testWidgets('dismissing the sheet keeps the month', (tester) async {
      final repo = _repoWith([
        period(2026, 10, counts: counts(expected: 3)),
        period(2026, 9, counts: counts(expected: 4)),
      ]);
      await _pump(tester, repo: repo);
      await tester.tap(find.text('Octubre de 2026'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Elige un mes'), findsNothing);
      expect(find.text('Octubre de 2026'), findsOneWidget);
      expect(repo.complianceCalls, hasLength(1));
    });

    testWidgets('a picked month survives a refresh while it is offered', (
      tester,
    ) async {
      final repo = _repoWith([
        period(2026, 10, counts: counts(expected: 3)),
        period(2026, 9, counts: counts(expected: 4)),
      ]);
      await _pump(tester, repo: repo, size: _short);
      await tester.tap(find.text('Octubre de 2026'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _sheet(),
          matching: find.text('Septiembre de 2026'),
        ),
      );
      await tester.pumpAndSettle();

      await _pullToRefresh(tester);

      expect(find.text('Septiembre de 2026'), findsOneWidget);
    });
  });

  group('clubs tab', () {
    testWidgets('is the default tab; the reports load once for its count', (
      tester,
    ) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      await _pump(tester, repo: repo);

      expect(repo.complianceCalls, hasLength(1));
      expect(repo.complianceCalls.single.page, 1);
      expect(repo.reportCalls, hasLength(1));
    });

    testWidgets('rows show name, sections, local field and the «x de y» chip', (
      tester,
    ) async {
      final repo = _repoWith(
        [period(2026, 10, counts: counts(expected: 3))],
        clubs: [
          clubCompliance(
            1,
            name: 'Club Orión',
            sections: const ['Aventureros', 'Conquistadores'],
            localField: 'Asociación Norte',
            counts: counts(expected: 3, submitted: 2, pending: 1),
          ),
          clubCompliance(
            2,
            name: 'Club Sin Campo',
            sections: const ['Guías Mayores'],
            localField: '',
            counts: counts(expected: 1, submitted: 1),
          ),
        ],
      );
      await _pump(tester, repo: repo);

      expect(find.text('Club Orión'), findsOneWidget);
      expect(
        find.text('Aventureros, Conquistadores · Asociación Norte'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row('Club Orión'), matching: find.text('2 de 3')),
        findsOneWidget,
      );
      expect(find.text('Club Sin Campo'), findsOneWidget);
      expect(find.text('Guías Mayores'), findsOneWidget);
      expect(
        find.descendant(
            of: _row('Club Sin Campo'), matching: find.text('1 de 1')),
        findsOneWidget,
      );
    });

    testWidgets('groups: «Con vencidos», «Pendientes» and «Al día», in order', (
      tester,
    ) async {
      final repo = _repoWith(
        [period(2026, 10, counts: counts(expected: 3))],
        clubs: [
          clubCompliance(
            1,
            name: 'Club Al Día',
            counts: counts(expected: 2, submitted: 2),
          ),
          clubCompliance(
            2,
            name: 'Club Pendiente',
            counts: counts(expected: 2, submitted: 1, pending: 1),
          ),
          clubCompliance(
            3,
            name: 'Club Vencido',
            counts: counts(expected: 4, submitted: 1, pending: 1, overdue: 2),
          ),
        ],
      );
      await _pump(tester, repo: repo);

      final overdue = tester.getTopLeft(find.text('CON VENCIDOS')).dy;
      final pending = tester.getTopLeft(find.text('PENDIENTES')).dy;
      final upToDate = tester.getTopLeft(find.text('AL DÍA')).dy;
      expect(overdue, lessThan(pending));
      expect(pending, lessThan(upToDate));
      // Overdue wins over pending for a club that has both.
      final vencido = tester.getTopLeft(find.text('Club Vencido')).dy;
      expect(vencido, greaterThan(overdue));
      expect(vencido, lessThan(pending));
    });

    testWidgets('chip tone: overdue error, pending warning, up to date success',
        (tester) async {
      final repo = _repoWith(
        [period(2026, 10, counts: counts(expected: 3))],
        clubs: [
          clubCompliance(1,
              name: 'A', counts: counts(expected: 2, submitted: 0, overdue: 2)),
          clubCompliance(2,
              name: 'B', counts: counts(expected: 2, submitted: 1, pending: 1)),
          clubCompliance(3,
              name: 'C', counts: counts(expected: 2, submitted: 2)),
        ],
      );
      await _pump(tester, repo: repo);

      SacTone toneOf(String club) => tester
          .widget<SupervisionStatusChip>(find.descendant(
            of: _row(club),
            matching: find.byType(SupervisionStatusChip),
          ))
          .tone;
      expect(toneOf('A'), SacTone.error);
      expect(toneOf('B'), SacTone.warning);
      expect(toneOf('C'), SacTone.success);
    });

    testWidgets('the segmented control shows the club and report counts', (
      tester,
    ) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onCompliance = (_) async => Right(
            compliancePage(
              [clubCompliance(1)],
              totals: counts(expected: 3),
              total: 21,
            ),
          );
      repo.onReports =
          (_) async => Right(reportPage([report('r1')], total: 25));
      await _pump(tester, repo: repo);

      final control = tester.widget<SupervisionSegmentedControl<Object?>>(
        find.byWidgetPredicate((w) => w is SupervisionSegmentedControl),
      );
      expect(control.segments.map((s) => s.label), ['Por club', 'Informes']);
      expect(control.segments.map((s) => s.count), [21, 25]);
    });

    testWidgets('a club expecting nothing says so', (tester) async {
      final repo = _repoWith(
        [period(2026, 10, counts: counts(expected: 3))],
        clubs: [clubCompliance(1, counts: counts())],
      );
      await _pump(tester, repo: repo);

      // Its own group, last, not «al día»: nothing was due.
      expect(find.text('SIN INFORMES ESPERADOS'), findsOneWidget);
      expect(find.text('AL DÍA'), findsNothing);
    });

    testWidgets('shows the empty state when no club had reports expected', (
      tester,
    ) async {
      final repo = _repoWith(
        [period(2026, 10, counts: counts(expected: 3))],
        clubs: const [],
      );
      await _pump(tester, repo: repo);

      expect(find.text('Sin clubes este mes'), findsOneWidget);
      expect(
        find.text('Ningún club de tu territorio tenía informes esperados.'),
        findsOneWidget,
      );
    });

    testWidgets('load more appends the next page', (tester) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onCompliance = (call) async => Right(
            call.page == 1
                ? compliancePage(
                    [clubCompliance(1, name: 'Club Uno')],
                    page: 1,
                    total: 2,
                    hasMore: true,
                  )
                : compliancePage(
                    [clubCompliance(2, name: 'Club Dos')],
                    page: 2,
                    total: 2,
                  ),
          );
      await _pump(tester, repo: repo);

      expect(repo.complianceCalls.map((c) => c.page), [1, 2]);
      expect(find.text('Club Uno'), findsOneWidget);
      expect(find.text('Club Dos'), findsOneWidget);
    });

    testWidgets('a failed next page keeps the clubs and offers a retry', (
      tester,
    ) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onCompliance = (call) async {
        if (call.page == 1) {
          return Right(
            compliancePage(
              [clubCompliance(1, name: 'Club Uno')],
              page: 1,
              total: 2,
              hasMore: true,
            ),
          );
        }
        final fails =
            repo.complianceCalls.where((c) => c.page == 2).length == 1;
        return fails
            ? const Left(kBoom)
            : Right(
                compliancePage(
                  [clubCompliance(2, name: 'Club Dos')],
                  page: 2,
                  total: 2,
                ),
              );
      };
      await _pump(tester, repo: repo);

      expect(find.text('Club Uno'), findsOneWidget);
      expect(find.text('No se pudo cargar más.'), findsOneWidget);
      // The failed page waits for the button instead of looping.
      expect(repo.complianceCalls.map((c) => c.page), [1, 2]);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Club Dos'), findsOneWidget);
      expect(find.text('No se pudo cargar más.'), findsNothing);
    });

    testWidgets('an error with no clubs shows the error state and retries', (
      tester,
    ) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onCompliance = (_) async => repo.complianceCalls.length == 1
          ? const Left(kBoom)
          : Right(compliancePage([clubCompliance(1, name: 'Club Orión')]));
      await _pump(tester, repo: repo);

      expect(find.text('No se pudieron cargar los informes'), findsOneWidget);
      // The header still stands on the numbers of the selector.
      expect(find.text('Octubre de 2026'), findsOneWidget);
      expect(find.byType(ForbiddenView), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.complianceCalls, hasLength(2));
      expect(find.text('No se pudieron cargar los informes'), findsNothing);
      expect(find.text('Club Orión'), findsOneWidget);
    });

    testWidgets('a 403 on compliance shows the forbidden state', (
      tester,
    ) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onCompliance = (_) async => const Left(kForbidden);
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('reports tab', () {
    Future<FakeReportsRepo> openReports(
      WidgetTester tester,
      FakeReportsRepo repo,
    ) async {
      await _pump(tester, repo: repo);
      await tester.tap(_tab('Informes'));
      await tester.pumpAndSettle();
      return repo;
    }

    FakeReportsRepo repoWithReports(List<SupervisionMonthlyReport> items) {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onReports = (_) async => Right(reportPage(items));
      return repo;
    }

    testWidgets('requests the reports of the month once, not per tab tap', (
      tester,
    ) async {
      final repo = repoWithReports([report('r1')]);
      await _pump(tester, repo: repo);
      expect(repo.reportCalls, hasLength(1));

      await tester.tap(_tab('Informes'));
      await tester.pumpAndSettle();

      expect(repo.reportCalls, hasLength(1));
      expect(repo.reportCalls.single.period, (year: 2026, month: 10));
      expect(repo.reportCalls.single.page, 1);
    });

    testWidgets('rows show club, type, local field group and the status chip', (
      tester,
    ) async {
      final sent = DateTime(2026, 11, 3, 10);
      final repo = repoWithReports([
        report(
          'r1',
          clubName: 'Club Enviado',
          submittedAt: sent,
        ),
        report('r2', clubName: 'Club Sin Fecha'),
        report(
          'r3',
          clubName: 'Club Generado',
          status: SupervisionReportStatus.generated,
          clubTypeName: 'Aventureros',
        ),
        report(
          'r4',
          clubName: 'Club Borrador',
          status: SupervisionReportStatus.draft,
          localFieldName: '',
        ),
      ]);
      await openReports(tester, repo);

      expect(find.text('Club Enviado'), findsOneWidget);
      // The local field is the group; the row keeps the club type.
      expect(find.text('ASOCIACIÓN NORTE'), findsOneWidget);
      expect(find.text('Conquistadores'), findsWidgets);
      expect(find.text('Enviado el ${_dayMonth(sent)}'), findsOneWidget);
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.text('Generado, sin enviar'), findsOneWidget);
      expect(find.text('Aventureros'), findsOneWidget);
      expect(find.text('Borrador, sin PDF'), findsOneWidget);
      // A report with no local field falls in a group of its own, last.
      expect(find.text('INFORMES'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('INFORMES')).dy,
        greaterThan(tester.getTopLeft(find.text('Club Enviado')).dy),
      );
    });

    testWidgets('status chips follow the club side: info, accent, warning', (
      tester,
    ) async {
      final repo = repoWithReports([
        report('r1',
            clubName: 'Club Enviado', submittedAt: DateTime(2026, 11, 3)),
        report('r2',
            clubName: 'Club Generado',
            status: SupervisionReportStatus.generated),
        report('r3',
            clubName: 'Club Borrador', status: SupervisionReportStatus.draft),
      ]);
      await openReports(tester, repo);

      SacTone toneOf(String club) => tester
          .widget<SupervisionStatusChip>(find.descendant(
            of: _row(club),
            matching: find.byType(SupervisionStatusChip),
          ))
          .tone;
      expect(toneOf('Club Enviado'), SacTone.info);
      expect(toneOf('Club Generado'), SacTone.accent);
      expect(toneOf('Club Borrador'), SacTone.warning);
    });

    testWidgets('a nameless club falls back to the generic label', (
      tester,
    ) async {
      final repo = repoWithReports([report('r1', clubName: '')]);
      await openReports(tester, repo);

      expect(find.text('Club sin nombre'), findsOneWidget);
    });

    testWidgets('a draft row is not tappable and has no PDF tile', (
      tester,
    ) async {
      final repo = repoWithReports([
        report(
          'r1',
          clubName: 'Club Borrador',
          status: SupervisionReportStatus.draft,
        ),
        report('r2', clubName: 'Club Enviado'),
      ]);
      await openReports(tester, repo);

      final draft = _row('Club Borrador');
      expect(tester.widget<SacListRow>(draft).onTap, isNull);
      expect(
        find.descendant(
          of: draft,
          matching: _icon(HugeIcons.strokeRoundedPdf01),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Club Borrador'));
      await tester.pumpAndSettle();
      expect(repo.pdfCalls, isEmpty);

      final sent = _row('Club Enviado');
      expect(tester.widget<SacListRow>(sent).onTap, isNotNull);
      expect(
        find.descendant(
          of: sent,
          matching: _icon(HugeIcons.strokeRoundedPdf01),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unknown status says so and has no PDF', (tester) async {
      final repo = repoWithReports([
        report('r1', status: SupervisionReportStatus.unknown),
      ]);
      await openReports(tester, repo);

      expect(find.text('Estado desconocido'), findsOneWidget);
      expect(_icon(HugeIcons.strokeRoundedPdf01), findsNothing);
    });

    testWidgets('shows the empty state when the month has no reports', (
      tester,
    ) async {
      await openReports(tester, repoWithReports(const []));

      expect(find.text('Aún no hay informes'), findsOneWidget);
      expect(find.byType(SacEmptyState), findsOneWidget);
    });

    testWidgets('load more appends the next page of reports', (tester) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onReports = (call) async => Right(
            call.page == 1
                ? reportPage(
                    [report('r1', clubName: 'Club Uno')],
                    total: 2,
                    hasMore: true,
                  )
                : reportPage(
                    [report('r2', clubName: 'Club Dos')],
                    page: 2,
                    total: 2,
                  ),
          );
      await openReports(tester, repo);

      expect(repo.reportCalls.map((c) => c.page), [1, 2]);
      expect(find.text('Club Uno'), findsOneWidget);
      expect(find.text('Club Dos'), findsOneWidget);
    });

    testWidgets('an error shows the error state and retry reloads', (
      tester,
    ) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onReports = (_) async => repo.reportCalls.length == 1
          ? const Left(kBoom)
          : Right(reportPage([report('r1', clubName: 'Club Uno')]));
      await openReports(tester, repo);

      expect(find.text('No se pudieron cargar los informes'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.reportCalls, hasLength(2));
      expect(find.text('Club Uno'), findsOneWidget);
    });

    testWidgets('switching back to «Por club» shows the compliance again', (
      tester,
    ) async {
      final repo = repoWithReports([report('r1', clubName: 'Club Informe')]);
      repo.onCompliance = (call) async => Right(
            compliancePage(
              [clubCompliance(1, name: 'Club Cumplimiento')],
              totals: counts(expected: 3),
            ),
          );
      await openReports(tester, repo);
      expect(find.text('Club Informe'), findsOneWidget);

      await tester.tap(_tab('Por club'));
      await tester.pumpAndSettle();

      expect(find.text('Club Cumplimiento'), findsOneWidget);
      expect(find.text('Club Informe'), findsNothing);
    });
  });

  group('PDF', () {
    Future<FakeReportsRepo> openReports(
      WidgetTester tester,
      FakeReportsRepo repo,
    ) async {
      await _pump(tester, repo: repo);
      await tester.tap(_tab('Informes'));
      await tester.pumpAndSettle();
      return repo;
    }

    FakeReportsRepo repoWithReport({String id = 'a1b2c3d4-uuid'}) {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      repo.onReports =
          (_) async => Right(reportPage([report(id, clubName: 'Club Orión')]));
      return repo;
    }

    testWidgets('tapping a report downloads it by its string id and opens it', (
      tester,
    ) async {
      final repo = repoWithReport();
      repo.onPdf = (_) async => const Right('/tmp/informe.pdf');
      await openReports(tester, repo);

      await tester.tap(find.text('Club Orión'));
      await tester.pumpAndSettle();

      expect(repo.pdfCalls, ['a1b2c3d4-uuid']);
      final viewer = tester.widget<SacPdfViewer>(find.byType(SacPdfViewer));
      expect(viewer.pdfSource, '/tmp/informe.pdf');
      expect(viewer.title, 'Club Orión');
    });

    testWidgets('a double tap downloads once and shows a spinner meanwhile', (
      tester,
    ) async {
      final gate = Completer<String>();
      final repo = repoWithReport();
      repo.onPdf = (_) async => Right(await gate.future);
      await openReports(tester, repo);
      expect(_icon(HugeIcons.strokeRoundedArrowRight01), findsOneWidget);
      expect(find.byType(SacLoadingSmall), findsNothing);

      await tester.tap(find.text('Club Orión'));
      await tester.pump();
      await tester.tap(find.text('Club Orión'));
      await tester.pump();

      // The spinner takes the place of the chevron, on the row.
      expect(repo.pdfCalls, hasLength(1));
      expect(find.byType(SacLoadingSmall), findsOneWidget);
      expect(_icon(HugeIcons.strokeRoundedArrowRight01), findsNothing);

      gate.complete('/tmp/informe.pdf');
      await tester.pumpAndSettle();

      expect(repo.pdfCalls, hasLength(1));
      expect(find.byType(SacPdfViewer), findsOneWidget);
    });

    testWidgets('a failure shows the generic snackbar and frees the card', (
      tester,
    ) async {
      final repo = repoWithReport();
      repo.onPdf = (_) async => const Left(kBoom);
      await openReports(tester, repo);

      await tester.tap(find.text('Club Orión'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo abrir el PDF. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.byType(SacPdfViewer), findsNothing);
      expect(find.byType(SacLoadingSmall), findsNothing);
      expect(_icon(HugeIcons.strokeRoundedArrowRight01), findsOneWidget);

      // The row is free again: a second tap asks again.
      await tester.tap(find.text('Club Orión'));
      await tester.pumpAndSettle();
      expect(repo.pdfCalls, hasLength(2));
    });

    testWidgets('a 403 shows the no-access snackbar', (tester) async {
      final repo = repoWithReport();
      repo.onPdf = (_) async => const Left(kForbidden);
      await openReports(tester, repo);

      await tester.tap(find.text('Club Orión'));
      await tester.pumpAndSettle();

      expect(find.text('No tienes acceso a este informe.'), findsOneWidget);
      expect(
        find.text('No se pudo abrir el PDF. Inténtalo de nuevo.'),
        findsNothing,
      );
      expect(find.byType(SacPdfViewer), findsNothing);
    });
  });

  group('empty and error states of the periods', () {
    testWidgets('no started periods shows the empty state', (tester) async {
      final repo = FakeReportsRepo()
        ..onPeriods = () async => Right(periods(const []));
      await _pump(tester, repo: repo);

      expect(find.text('Aún no hay meses que revisar'), findsOneWidget);
      expect(repo.complianceCalls, isEmpty);
      expect(_tab('Por club'), findsNothing);
    });

    testWidgets('a periods error shows the error state and retry reloads', (
      tester,
    ) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      final ok = repo.onPeriods;
      repo.onPeriods =
          () async => repo.periodsCalls == 1 ? const Left(kBoom) : ok();
      await _pump(tester, repo: repo);

      expect(find.text('No se pudieron cargar los informes'), findsOneWidget);
      expect(find.byType(SacErrorState), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.periodsCalls, 2);
      expect(find.text('Octubre de 2026'), findsOneWidget);
    });

    testWidgets('a periods 403 shows the forbidden state', (tester) async {
      final repo = FakeReportsRepo()
        ..onPeriods = () async => const Left(kForbidden);
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('No se pudieron cargar los informes'), findsNothing);
    });
  });

  group('pull to refresh', () {
    testWidgets('reloads the periods and the clubs', (tester) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      await _pump(tester, repo: repo, size: _short);
      expect(repo.periodsCalls, 1);
      expect(repo.complianceCalls, hasLength(1));

      await _pullToRefresh(tester);

      expect(repo.periodsCalls, 2);
      expect(repo.complianceCalls, hasLength(2));
      // The reports feed the tab count: they reload with the rest.
      expect(repo.reportCalls, hasLength(2));
      expect(find.text('Octubre de 2026'), findsOneWidget);
    });

    testWidgets('on the reports tab it reloads the reports too', (
      tester,
    ) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      await _pump(tester, repo: repo, size: _short);
      await tester.tap(_tab('Informes'));
      await tester.pumpAndSettle();
      expect(repo.reportCalls, hasLength(1));

      await _pullToRefresh(tester);

      expect(repo.periodsCalls, 2);
      expect(repo.reportCalls, hasLength(2));
    });

    testWidgets('on the error state it reloads the periods', (tester) async {
      final repo = _repoWith([period(2026, 10, counts: counts(expected: 3))]);
      final ok = repo.onPeriods;
      repo.onPeriods =
          () async => repo.periodsCalls == 1 ? const Left(kBoom) : ok();
      await _pump(tester, repo: repo, size: _short);

      await _pullToRefresh(tester);

      expect(repo.periodsCalls, 2);
      expect(find.text('Octubre de 2026'), findsOneWidget);
    });
  });

  group('layout at 320x640 with text scale 2.0', () {
    final bigCounts = counts(
      expected: 9999999,
      submitted: 1234567,
      pending: 7654321,
      overdue: 1111111,
    );

    FakeReportsRepo narrowRepo() {
      final started = [
        period(2026, 10, dueAt: DateTime(2026, 10, 31), counts: bigCounts),
        period(2026, 9, counts: bigCounts),
        period(2026, 8, counts: bigCounts),
      ];
      final repo = _repoWith(
        started,
        clubs: [
          for (var i = 1; i <= 3; i++)
            clubCompliance(
              i,
              name: '$_longName $i',
              localField: 'Asociación Central del Valle Grande y Lejano',
              sections: const [
                'Aventureros',
                'Conquistadores',
                'Guías Mayores',
              ],
              counts: bigCounts,
            ),
        ],
      );
      repo.onReports = (_) async => Right(
            reportPage([
              for (var i = 1; i <= 3; i++)
                report(
                  'r$i',
                  clubName: '$_longName $i',
                  clubTypeName: 'Guías Mayores y Líderes Voluntarios',
                  localFieldName: 'Asociación Central del Valle Grande',
                  submittedAt: DateTime(2026, 11, 30),
                ),
            ]),
          );
      return repo;
    }

    testWidgets('clubs tab does not overflow', (tester) async {
      await _pump(
        tester,
        repo: narrowRepo(),
        size: _narrow,
        textScale: 2.0,
      );

      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.textContaining('Club de Conquistadores'), findsWidgets);
      expectNoLayoutException(tester);
    });

    testWidgets('clubs tab does not overflow after scrolling to the end', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: narrowRepo(),
        size: _narrow,
        textScale: 2.0,
      );

      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
    });

    testWidgets('reports tab does not overflow', (tester) async {
      await _pump(
        tester,
        repo: narrowRepo(),
        size: _narrow,
        textScale: 2.0,
      );
      await _scrollTo(tester, _tab('Informes'));
      await tester.tap(_tab('Informes'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('$_longName 3'));

      expect(find.textContaining('Enviado el'), findsWidgets);
      expectNoLayoutException(tester);
    });

    testWidgets('month sheet does not overflow', (tester) async {
      await _pump(
        tester,
        repo: narrowRepo(),
        size: _narrow,
        textScale: 2.0,
      );
      await tester.tap(find.text('Octubre de 2026'));
      await tester.pumpAndSettle();

      expect(find.text('Elige un mes'), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('error and empty states do not overflow', (tester) async {
      final repo = _repoWith([period(2026, 10, counts: bigCounts)]);
      repo.onCompliance = (_) async => const Left(kBoom);
      await _pump(tester, repo: repo, size: _narrow, textScale: 2.0);

      // The big box and control come first at this scale: scroll to it.
      await _scrollTo(tester, find.text('No se pudieron cargar los informes'));
      expect(find.text('No se pudieron cargar los informes'), findsOneWidget);
      expectNoLayoutException(tester);
    });
  });
}
