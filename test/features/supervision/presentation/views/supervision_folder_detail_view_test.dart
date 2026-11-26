/// Widget tests for one annual folder: state panel, points box, sections
/// grouped by what they need and the closing of the folder. The section has
/// its own screen (`supervision_folder_section_view_test.dart`).
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_frosted_footer.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_folder_detail_view.dart';

import 'supervision_folders_test_harness.dart';
import 'supervision_view_test_harness.dart';

const _evaluator = [kSupervisionAppView, kEvaluateCap];
const _union = [kSupervisionAppView, kConfirmUnionCap];

const _submitted = SupervisionSectionStatus.submitted;
const _preapproved = SupervisionSectionStatus.preapprovedLf;
const _validated = SupervisionSectionStatus.validated;
const _rejected = SupervisionSectionStatus.rejected;
const _pendingSection = SupervisionSectionStatus.pending;

Future<FakeFoldersRepo> _pump(
  WidgetTester tester, {
  FakeFoldersRepo? repo,
  List<String> capabilities = _evaluator,
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeFoldersRepo();
  await pumpFoldersApp(
    tester,
    home: const SupervisionFolderDetailView(folderId: 'f1'),
    repo: fake,
    capabilities: capabilities,
    size: size,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}

/// A repo whose folder holds [sections] (one by default).
FakeFoldersRepo _repoWith({
  List<SupervisionFolderSection>? sections,
  SupervisionFolderStatus status = SupervisionFolderStatus.submitted,
  bool requiresUnion = false,
}) =>
    FakeFoldersRepo()
      ..onFolder = (_) async => Right(folderDetail(
            status: status,
            requiresUnionConfirmation: requiresUnion,
            sections: sections,
          ));

Finder _button(String text) => find.widgetWithText(SacButton, text);

Finder _dialogButton(String text) => find.descendant(
      of: find.byType(SacDialog),
      matching: find.widgetWithText(SacButton, text),
    );

Finder _row(String label, {String? value}) => find.byWidgetPredicate(
      (w) =>
          w is SacValueRow &&
          w.label == label &&
          (value == null || w.value == value),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initSupervisionViewTests);

  group('load states', () {
    testWidgets('shows the skeleton while the folder loads', (tester) async {
      final gate = Completer<FolderResult>();
      final repo = FakeFoldersRepo()..onFolder = (_) => gate.future;
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.byType(SacErrorState), findsNothing);
      expect(find.text('Carpeta anual'), findsOneWidget);

      gate.complete(Right(folderDetail()));
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Sección s1'), findsOneWidget);
    });

    testWidgets('shows the error state and retry reloads the folder', (
      tester,
    ) async {
      final repo = FakeFoldersRepo();
      repo.onFolder = (_) async => repo.folderCalls.length == 1
          ? const Left(kBoom)
          : Right(folderDetail());
      await _pump(tester, repo: repo);

      expect(find.text('No se pudo cargar la carpeta'), findsOneWidget);
      expect(find.byType(ForbiddenView), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.folderCalls, ['f1', 'f1']);
      expect(find.text('No se pudo cargar la carpeta'), findsNothing);
      expect(find.text('Sección s1'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = FakeFoldersRepo()
        ..onFolder =
            (_) async => const Left(AuthFailure(message: 'nope', code: 403));
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('No se pudo cargar la carpeta'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('top bar shows the club and "type · year"', (tester) async {
      await _pump(tester);

      expect(find.text('Club Orión'), findsOneWidget);
      expect(find.text('Conquistadores · 2026'), findsOneWidget);
    });

    testWidgets('top bar falls back to the generic title without a club name', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(clubName: ' '));
      await _pump(tester, repo: repo);

      expect(find.text('Carpeta anual'), findsOneWidget);
    });
  });

  group('state panel', () {
    Future<void> pumpStatus(
      WidgetTester tester,
      SupervisionFolderStatus status, {
      DateTime? submittedAt,
      List<SupervisionFolderSection>? sections,
    }) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(
              status: status,
              submittedAt: submittedAt,
              sections: sections,
            ));
      await _pump(tester, repo: repo);
    }

    testWidgets('shows the status once, with how many sections wait', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        SupervisionFolderStatus.underEvaluation,
        submittedAt: DateTime(2026, 3, 14),
        sections: [
          section('a', status: _submitted),
          section('b', status: _submitted),
          section('c', status: _validated, earnedPoints: 80),
        ],
      );

      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(find.text('En evaluación'), findsOneWidget);
      expect(
        find.text(
            '2 de 3 secciones esperan tu evaluación. Enviada el ${intl.DateFormat.yMMMd('es').format(DateTime(2026, 3, 14))}.'),
        findsOneWidget,
      );
      expect(find.text('Ver todos los estados'), findsOneWidget);
      // The old summary rows are gone.
      expect(_row('Estado'), findsNothing);
      expect(_row('Avance'), findsNothing);
    });

    for (final (status, message) in [
      (SupervisionFolderStatus.open, 'El club aún está armando su carpeta.'),
      (
        SupervisionFolderStatus.evaluated,
        'Todas las secciones enviadas ya tienen evaluación.'
      ),
      (
        SupervisionFolderStatus.closed,
        'El club ya no puede cambiar evidencias.'
      ),
    ]) {
      testWidgets('a ${status.name} folder says "$message"', (tester) async {
        await pumpStatus(tester, status);

        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('tapping it lists every state, the current one marked', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        SupervisionFolderStatus.underEvaluation,
        submittedAt: DateTime(2026, 3, 14),
      );

      await _tap(tester, find.byType(SacStatePanel));

      expect(find.byType(SacStatesSheet), findsOneWidget);
      expect(find.text('Estados de la carpeta'), findsOneWidget);
      for (final state in [
        'Abierta',
        'Enviada',
        'En evaluación',
        'Evaluada',
        'Cerrada',
      ]) {
        expect(
          find.descendant(
              of: find.byType(SacStatesSheet), matching: find.text(state)),
          findsOneWidget,
          reason: state,
        );
      }
      expect(
        find.descendant(
            of: find.byType(SacStatesSheet),
            matching: find.text(
                intl.DateFormat.yMMMd('es').format(DateTime(2026, 3, 14)))),
        findsOneWidget,
      );
    });
  });

  group('points box', () {
    testWidgets('shows earned points, maximum and percentage', (tester) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(
              totalEarnedPoints: 1240,
              totalMaxPoints: 3000,
              progressPercentage: 41.3,
            ));
      await _pump(tester, repo: repo);

      expect(find.text('Puntos de la carpeta'), findsOneWidget);
      expect(find.text('Máx. 3,000 pts'), findsOneWidget);
      expect(find.textContaining('1,240'), findsOneWidget);
      expect(find.textContaining('41%'), findsOneWidget);
    });

    testWidgets('the percentage never goes above 100', (tester) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(progressPercentage: 150));
      await _pump(tester, repo: repo);

      expect(find.textContaining('100%'), findsOneWidget);
    });

    testWidgets('a negative percentage reads 0%', (tester) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(progressPercentage: -5));
      await _pump(tester, repo: repo);

      expect(find.textContaining('  ·  0%'), findsOneWidget);
    });

    testWidgets(
        'the legend splits validated, waiting for the Union and to evaluate', (
      tester,
    ) async {
      final repo = _repoWith(sections: [
        section('a', status: _validated, earnedPoints: 320, maxPoints: 400),
        section('b', status: _preapproved, earnedPoints: 400, maxPoints: 400),
        section('c', status: _submitted, maxPoints: 500),
        section('d', status: _submitted, maxPoints: 300),
        section('e', status: _rejected, earnedPoints: 0, maxPoints: 200),
      ]);
      await _pump(tester, repo: repo);

      expect(find.textContaining('Validados 320'), findsOneWidget);
      expect(find.textContaining('Esperan a la Unión 400'), findsOneWidget);
      expect(find.textContaining('Por evaluar 800'), findsOneWidget);
    });

    testWidgets('a legend entry with nothing in it is left out', (
      tester,
    ) async {
      final repo = _repoWith(sections: [
        section('a', status: _submitted, maxPoints: 100),
      ]);
      await _pump(tester, repo: repo);

      expect(find.textContaining('Por evaluar 100'), findsOneWidget);
      expect(find.textContaining('Validados'), findsNothing);
      expect(find.textContaining('Esperan a la Unión'), findsNothing);
    });
  });

  group('sections list', () {
    testWidgets('groups them by what they need, with a tone icon each', (
      tester,
    ) async {
      final repo = _repoWith(sections: [
        section('a', name: 'Secretaría', status: _submitted, maxPoints: 100),
        section('b', name: 'Tesorería', status: _pendingSection, maxPoints: 50),
        section('c',
            name: 'Misiones',
            status: _preapproved,
            maxPoints: 100,
            earnedPoints: 70),
        section('d',
            name: 'Camping',
            status: _validated,
            maxPoints: 100,
            earnedPoints: 80),
        section('e',
            name: 'Deportes',
            status: _rejected,
            maxPoints: 100,
            earnedPoints: 0),
      ]);
      await _pump(tester, repo: repo);

      expect(find.text('POR EVALUAR'), findsOneWidget);
      expect(find.text('EVALUADAS'), findsOneWidget);
      expect(find.text('SIN ENVIAR'), findsOneWidget);
      expect(find.text('Secretaría'), findsOneWidget);
      expect(
        find.descendant(
            of: find.byType(SacListRow), matching: find.text('Máx. 100 pts')),
        findsOneWidget,
      );
      expect(find.text('Sin enviar · Máx. 50 pts'), findsOneWidget);
      // Waiting for the Union: not the evaluator's to do, so "evaluated".
      expect(find.text('Evaluada, espera a la Unión · 70 de 100 pts'),
          findsOneWidget);
      expect(find.text('Validada · 80 de 100 pts'), findsOneWidget);
      // Zero earned points is an evaluation, not "not evaluated".
      expect(find.text('Rechazada · 0 de 100 pts'), findsOneWidget);

      final tones = tester
          .widgetList<SacListRowIcon>(find.byType(SacListRowIcon))
          .map((i) => i.tone)
          .toList();
      expect(tones, [
        SacTone.warning,
        SacTone.info,
        SacTone.success,
        SacTone.error,
        SacTone.muted,
      ]);
    });

    testWidgets('a submitted section counts its evidences', (tester) async {
      final repo = _repoWith(sections: [
        section('a', status: _submitted, evidences: [
          evidence('e1'),
          evidence('e2'),
          evidence('e3'),
        ]),
        section('b', status: _submitted, evidences: [evidence('e4')]),
      ]);
      await _pump(tester, repo: repo);

      expect(find.text('Máx. 100 pts · 3 evidencias'), findsOneWidget);
      expect(find.text('Máx. 100 pts · 1 evidencia'), findsOneWidget);
    });

    testWidgets('what waits for the Union is "to evaluate" for the Union', (
      tester,
    ) async {
      final repo = _repoWith(
        sections: [
          section('a', status: _preapproved, earnedPoints: 70),
          section('b', status: _validated, earnedPoints: 80),
        ],
        requiresUnion: true,
      );
      await _pump(tester, repo: repo, capabilities: _union);

      expect(find.text('POR EVALUAR'), findsOneWidget);
      expect(find.text('EVALUADAS'), findsOneWidget);
      expect(find.textContaining('Esperan a la Unión 70'), findsOneWidget);
    });

    testWidgets('an empty group is not drawn', (tester) async {
      final repo = _repoWith(sections: [
        section('a', status: _validated, earnedPoints: 80),
      ]);
      await _pump(tester, repo: repo);

      expect(find.text('POR EVALUAR'), findsNothing);
      expect(find.text('SIN ENVIAR'), findsNothing);
      expect(find.text('EVALUADAS'), findsOneWidget);
    });

    testWidgets('a folder without sections still renders the panel', (
      tester,
    ) async {
      final repo = _repoWith(sections: const []);
      await _pump(tester, repo: repo);

      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(find.byType(SacListRow), findsNothing);
    });

    testWidgets('tapping a section opens its own screen', (tester) async {
      await _pump(tester);

      await _tap(tester, find.widgetWithText(SacListRow, 'Sección s1').first);

      expect(find.text('section:f1/s1'), findsOneWidget);
    });
  });

  group('close folder', () {
    Future<void> pumpWith(
      WidgetTester tester, {
      FakeFoldersRepo? repo,
      List<String> capabilities = _evaluator,
      SupervisionFolderStatus status = SupervisionFolderStatus.submitted,
    }) async {
      await _pump(
        tester,
        repo: repo ?? _repoWith(status: status),
        capabilities: capabilities,
      );
    }

    for (final status in [
      SupervisionFolderStatus.submitted,
      SupervisionFolderStatus.evaluated,
    ]) {
      testWidgets(
          'is offered for a ${status.name} folder with folders.evaluate',
          (tester) async {
        await pumpWith(tester, status: status);

        expect(_button('Cerrar carpeta'), findsOneWidget);
      });
    }

    for (final status in [
      SupervisionFolderStatus.open,
      SupervisionFolderStatus.underEvaluation,
      SupervisionFolderStatus.closed,
      SupervisionFolderStatus.unknown,
    ]) {
      testWidgets('is hidden for a ${status.name} folder', (tester) async {
        await pumpWith(tester, status: status);

        expect(_button('Cerrar carpeta'), findsNothing);
      });
    }

    testWidgets('is the fixed footer action, with what closing means', (
      tester,
    ) async {
      await pumpWith(tester);

      expect(find.byType(SacFrostedFooter), findsOneWidget);
      expect(find.text('Al cerrarla, el club ya no puede cambiar evidencias.'),
          findsOneWidget);
      expect(tester.widget<SacButton>(_button('Cerrar carpeta')).variant,
          SacButtonVariant.primary);
    });

    testWidgets('is hidden without folders.evaluate', (tester) async {
      await pumpWith(tester, capabilities: _union);

      expect(_button('Cerrar carpeta'), findsNothing);
    });

    testWidgets('confirming closes the folder and shows the success toast', (
      tester,
    ) async {
      final repo = _repoWith();
      await pumpWith(tester, repo: repo);

      await _tap(tester, _button('Cerrar carpeta'));
      expect(find.text('¿Cerrar la carpeta?'), findsOneWidget);
      expect(repo.closeCalls, isEmpty);

      await _tap(tester, _dialogButton('Cerrar carpeta'));

      expect(repo.closeCalls, ['f1']);
      expect(find.text('Carpeta cerrada'), findsOneWidget);
      expect(find.byType(SacDialog), findsNothing);
    });

    testWidgets('cancelling does not close the folder', (tester) async {
      final repo = _repoWith();
      await pumpWith(tester, repo: repo);

      await _tap(tester, _button('Cerrar carpeta'));
      await _tap(tester, _dialogButton('Cancelar'));

      expect(repo.closeCalls, isEmpty);
      expect(find.byType(SacDialog), findsNothing);
      expect(find.text('Carpeta cerrada'), findsNothing);
    });

    testWidgets('a failure shows the server message in an error toast', (
      tester,
    ) async {
      final repo = _repoWith()
        ..onClose = () async => Left(codedFailure('X', 'Faltan secciones'));
      await pumpWith(tester, repo: repo);

      await _tap(tester, _button('Cerrar carpeta'));
      await _tap(tester, _dialogButton('Cerrar carpeta'));

      expect(repo.closeCalls, ['f1']);
      expect(find.text('Faltan secciones'), findsOneWidget);
      expect(find.text('Carpeta cerrada'), findsNothing);
    });

    testWidgets('the button shows a loading state while closing', (
      tester,
    ) async {
      final gate = Completer<ActionResult>();
      final repo = _repoWith()..onClose = () => gate.future;
      await pumpWith(tester, repo: repo);

      await _tap(tester, _button('Cerrar carpeta'));
      await tester.tap(_dialogButton('Cerrar carpeta'));
      await tester.pump();
      // Lets the dialog route finish closing; the spinner never settles.
      await tester.pump(const Duration(seconds: 1));

      expect(tester.widget<SacButton>(_button('Cerrar carpeta')).isLoading,
          isTrue);

      gate.complete(const Right(unit));
      await tester.pumpAndSettle();
      expect(tester.widget<SacButton>(_button('Cerrar carpeta')).isLoading,
          isFalse);
      expect(find.text('Carpeta cerrada'), findsOneWidget);
    });

    // BUG (low): `result.errorMessage ?? 'common.error_generic'.tr()` in
    // supervision_folder_detail_view.dart:84 only falls back on null, so a
    // failure with an empty message shows an empty toast. Failing assertion:
    // find.text('Ocurrió un error. Inténtalo de nuevo.') -> 0 widgets.
    testWidgets(
        'a failure with a blank message falls back to the generic '
        'error', (tester) async {
      final repo = _repoWith()
        ..onClose = () async => const Left(ServerFailure(message: ''));
      await pumpWith(tester, repo: repo);

      await _tap(tester, _button('Cerrar carpeta'));
      await _tap(tester, _dialogButton('Cerrar carpeta'));

      expect(
          find.text('Ocurrió un error. Inténtalo de nuevo.'), findsOneWidget);
    });
  });

  group('layout robustness', () {
    const narrow = Size(320, 1600);

    SupervisionFolderSection longSection(
            String id, SupervisionSectionStatus st) =>
        section(
          id,
          name: 'Sección de tesorería y finanzas del club de la asociación',
          status: st,
          maxPoints: 100,
          earnedPoints: st == _submitted ? null : 70,
          evidences: [evidence('e$id')],
        );

    testWidgets('page at 320 wide and text scale 2.0 does not overflow', (
      tester,
    ) async {
      final repo = _repoWith(sections: [
        longSection('a', _submitted),
        longSection('b', _preapproved),
        section('c', status: _pendingSection),
      ]);
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);

      expectNoLayoutException(tester);
      expect(find.byType(SacListRow), findsNWidgets(3));
      expect(_button('Cerrar carpeta'), findsOneWidget);
    });

    testWidgets('page with every state context at 320 wide does not overflow',
        (tester) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(
              status: SupervisionFolderStatus.underEvaluation,
              submittedAt: DateTime(2026, 3, 14),
              sections: [
                longSection('a', _submitted),
                longSection('b', _validated),
              ],
            ));
      await _pump(tester, repo: repo, size: narrow);

      expectNoLayoutException(tester);
    });

    testWidgets('states sheet at 320 wide and text scale 2.0 does not overflow',
        (tester) async {
      await _pump(tester, size: narrow, textScale: 2.0);
      await _tap(tester, find.byType(SacStatePanel));

      expectNoLayoutException(tester);
      expect(find.byType(SacStatesSheet), findsOneWidget);
    });

    testWidgets('error state at 320 wide and text scale 2.0 does not overflow',
        (tester) async {
      final repo = FakeFoldersRepo()..onFolder = (_) async => const Left(kBoom);
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);

      expectNoLayoutException(tester);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets(
        'each section row is one button labelled with name and '
        'status', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = _repoWith(sections: [
        section('a', name: 'Secretaría', status: _submitted),
        section('b', name: 'Tesorería', status: _validated, earnedPoints: 80),
      ]);
      await _pump(tester, repo: repo);

      final expected = {
        'Secretaría': 'Máx. 100 pts',
        'Tesorería': 'Validada',
      };
      for (final entry in expected.entries) {
        final finder = find.bySemanticsLabel(
          RegExp('${entry.key}.*${entry.value}', dotAll: true),
        );
        expect(finder, findsOneWidget, reason: entry.key);
        final data = tester.getSemantics(finder);
        expect(data.flagsCollection.isButton, isTrue, reason: entry.key);
        expect(data.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: entry.key);
      }
      handle.dispose();
    });

    testWidgets('the state panel is one button that opens the states', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      final finder = find.bySemanticsLabel(RegExp('Enviada.*'));
      expect(finder, findsWidgets);
      final panel = tester.getSemantics(find.byType(SacStatePanel));
      expect(panel.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });
}
