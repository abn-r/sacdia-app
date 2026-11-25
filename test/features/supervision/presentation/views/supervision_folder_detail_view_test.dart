/// Widget tests for one annual folder: summary, sections list, the closing of
/// the folder and the section sheet (evaluation, Union confirmation, reopen,
/// reviewer notes).
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
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_folder_detail_view.dart';

import 'supervision_folders_test_harness.dart';
import 'supervision_view_test_harness.dart';

const _evaluator = [kSupervisionAppView, kEvaluateCap];
const _union = [kSupervisionAppView, kConfirmUnionCap];
const _both = [kSupervisionAppView, kEvaluateCap, kConfirmUnionCap];

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
  String localFieldName = 'Asociación Norte',
  String templateName = 'Plantilla 2026',
}) =>
    FakeFoldersRepo()
      ..onFolder = (_) async => Right(folderDetail(
            status: status,
            requiresUnionConfirmation: requiresUnion,
            sections: sections,
            localFieldName: localFieldName,
            templateName: templateName,
          ));

/// Pumps a folder with one section and opens its sheet.
Future<FakeFoldersRepo> _pumpSheet(
  WidgetTester tester, {
  SupervisionFolderSection? section,
  List<String> capabilities = _evaluator,
  SupervisionFolderStatus status = SupervisionFolderStatus.submitted,
  bool requiresUnion = false,
  FakeFoldersRepo? repo,
  Size? size,
  double? textScale,
}) async {
  final fake = repo ??
      _repoWith(
        sections: [section ?? _section()],
        status: status,
        requiresUnion: requiresUnion,
      );
  await _pump(
    tester,
    repo: fake,
    capabilities: capabilities,
    size: size,
    textScale: textScale,
  );
  await tester.tap(find.widgetWithText(SacListRow, 'Sección s1').first);
  await tester.pumpAndSettle();
  return fake;
}

SupervisionFolderSection _section({
  SupervisionSectionStatus status = _submitted,
  int? earnedPoints,
  String? evaluationNotes,
  List<SupervisionFolderEvidence> evidences = const [],
}) =>
    section(
      's1',
      status: status,
      earnedPoints: earnedPoints,
      evaluationNotes: evaluationNotes,
      evidences: evidences,
    );

Finder get _sheet => find.byType(BottomSheet);

Finder _sheetText(String text) =>
    find.descendant(of: _sheet.last, matching: find.text(text));

/// Labels of every [SacButton] in the open bottom sheets.
List<String> _sheetButtons(WidgetTester tester) => tester
    .widgetList<SacButton>(
      find.descendant(of: _sheet, matching: find.byType(SacButton)),
    )
    .map((b) => b.text)
    .toList();

Finder _button(String text) => find.widgetWithText(SacButton, text);

Finder _dialogButton(String text) => find.descendant(
      of: find.byType(SacDialog),
      matching: find.widgetWithText(SacButton, text),
    );

Finder _row(String label, {String? value, bool inSheet = false}) {
  final rows = find.byWidgetPredicate(
    (w) =>
        w is SacValueRow &&
        w.label == label &&
        (value == null || w.value == value),
  );
  return inSheet ? find.descendant(of: _sheet, matching: rows) : rows;
}

Finder _rowValueMatching(String label, RegExp value) => find.byWidgetPredicate(
      (w) => w is SacValueRow && w.label == label && value.hasMatch(w.value),
    );

Finder _noteRow(String fileName) => find.widgetWithText(SacListRow, fileName);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterPoints(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextFormField).first, text);
  await tester.pump();
}

/// Opens the evaluate sheet from the section sheet.
Future<void> _openEvaluate(WidgetTester tester) async {
  await _tap(tester, _button('Evaluar'));
  expect(find.text('Evaluar sección'), findsOneWidget);
}

/// Confirm button of the evaluate sheet (the section sheet keeps its own).
Finder get _evaluateConfirm => _button('Evaluar').last;

Future<void> _evaluateWith(
  WidgetTester tester,
  String points, {
  String? notes,
}) async {
  await _openEvaluate(tester);
  await _enterPoints(tester, points);
  if (notes != null) {
    await tester.enterText(find.byType(TextFormField).last, notes);
    await tester.pump();
  }
  await _tap(tester, _evaluateConfirm);
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

  group('summary', () {
    testWidgets('shows status, points, progress and the optional rows', (
      tester,
    ) async {
      final submittedAt = DateTime(2026, 3, 14);
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(
              status: SupervisionFolderStatus.underEvaluation,
              totalEarnedPoints: 40,
              totalMaxPoints: 120,
              progressPercentage: 40,
              submittedAt: submittedAt,
            ));
      await _pump(tester, repo: repo);

      expect(_row('Estado', value: 'En evaluación'), findsOneWidget);
      expect(_row('Puntos', value: '40 de 120 pts'), findsOneWidget);
      expect(_rowValueMatching('Avance', RegExp(r'^40\s*%$')), findsOneWidget);
      expect(_row('Campo local', value: 'Asociación Norte'), findsOneWidget);
      expect(_row('Plantilla', value: 'Plantilla 2026'), findsOneWidget);
      expect(
        _row('Enviada', value: intl.DateFormat.yMMMd('es').format(submittedAt)),
        findsOneWidget,
      );
    });

    testWidgets('optional rows are absent when empty', (tester) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(
              localFieldName: ' ',
              templateName: '',
            ));
      await _pump(tester, repo: repo);

      expect(_row('Estado'), findsOneWidget);
      expect(_row('Puntos'), findsOneWidget);
      expect(_row('Avance'), findsOneWidget);
      expect(_row('Campo local'), findsNothing);
      expect(_row('Plantilla'), findsNothing);
      expect(_row('Enviada'), findsNothing);
    });

    testWidgets('progress is clamped between 0 and 100 percent', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(progressPercentage: 150));
      await _pump(tester, repo: repo);

      expect(_rowValueMatching('Avance', RegExp(r'^100\s*%$')), findsOneWidget);
    });

    testWidgets('a negative progress shows 0 percent', (tester) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(progressPercentage: -5));
      await _pump(tester, repo: repo);

      expect(_rowValueMatching('Avance', RegExp(r'^0\s*%$')), findsOneWidget);
    });
  });

  group('sections list', () {
    testWidgets('shows each section with its status label and points', (
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

      expect(find.text('Secretaría'), findsOneWidget);
      expect(find.text('Por evaluar · Máx. 100 pts'), findsOneWidget);
      expect(find.text('Sin enviar · Máx. 50 pts'), findsOneWidget);
      expect(find.text('Evaluada, espera a la Unión · 70 de 100 pts'),
          findsOneWidget);
      expect(find.text('Validada · 80 de 100 pts'), findsOneWidget);
      // Zero earned points is an evaluation, not "not evaluated".
      expect(find.text('Rechazada · 0 de 100 pts'), findsOneWidget);
    });

    testWidgets('a folder without sections still renders the summary', (
      tester,
    ) async {
      final repo = _repoWith(sections: const []);
      await _pump(tester, repo: repo);

      expect(_row('Estado'), findsOneWidget);
      expect(find.byType(SacListRow), findsNothing);
    });

    testWidgets('tapping a section opens its sheet', (tester) async {
      await _pumpSheet(tester);

      expect(_sheet, findsOneWidget);
      expect(find.byType(SacSheetHeader), findsOneWidget);
      expect(_sheetText('Sección s1'), findsOneWidget);
      expect(_sheetText('Por evaluar · Máx. 100 pts'), findsOneWidget);
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

  group('section sheet content', () {
    testWidgets('shows description, evaluation facts and evidences', (
      tester,
    ) async {
      final when = DateTime(2026, 4, 2);
      final repo = _repoWith(sections: [
        section(
          's1',
          status: _validated,
          earnedPoints: 80,
          description: 'Entrega el acta anual firmada',
          evaluationNotes: 'Todo en orden',
          lfApproverName: 'Marta Ruiz',
          lfApprovedAt: when,
          unionApproverName: 'Luis Pérez',
          unionApprovedAt: when,
          evidences: [evidence('e1', fileName: 'acta.pdf')],
        ),
      ]);
      await _pumpSheet(tester, repo: repo);

      final date = intl.DateFormat.yMMMd('es').format(when);
      expect(_sheetText('Entrega el acta anual firmada'), findsOneWidget);
      expect(_row('Puntos', value: '80 de 100 pts', inSheet: true),
          findsOneWidget);
      expect(
          _row('Notas', value: 'Todo en orden', inSheet: true), findsOneWidget);
      expect(
          _row('Evaluó', value: 'Marta Ruiz', inSheet: true), findsOneWidget);
      expect(_row('Fecha', value: date, inSheet: true), findsOneWidget);
      expect(_row('Unión', value: 'Luis Pérez', inSheet: true), findsOneWidget);
      expect(_row('Confirmada', value: date, inSheet: true), findsOneWidget);
      expect(_sheetText('EVIDENCIAS'), findsOneWidget);
      expect(_sheetText('NOTAS DE REVISIÓN'), findsOneWidget);
      // File tile of the gallery plus the row of the notes list.
      expect(_sheetText('acta.pdf'), findsNWidgets(2));
    });

    testWidgets('a section never evaluated has no evaluation group', (
      tester,
    ) async {
      await _pumpSheet(tester);

      expect(_sheetText('EVALUACIÓN'), findsNothing);
      expect(_row('Evaluó', inSheet: true), findsNothing);
      expect(_row('Unión', inSheet: true), findsNothing);
      expect(_row('Confirmada', inSheet: true), findsNothing);
      // No evidences: the gallery empty state, no notes group.
      expect(_sheetText('EVIDENCIAS'), findsOneWidget);
      expect(_sheetText('NOTAS DE REVISIÓN'), findsNothing);
    });

    testWidgets('a reviewer note without text reads "Sin nota"', (
      tester,
    ) async {
      final repo = _repoWith(sections: [
        _section(evidences: [
          evidence('e1', fileName: 'acta.pdf', reviewerNote: 'Falta firma'),
          evidence('e2', fileName: 'foto.pdf'),
          evidence('e3', fileName: 'otra.pdf', reviewerNote: '   '),
        ]),
      ]);
      await _pumpSheet(tester, repo: repo);

      expect(_sheetText('Falta firma'), findsOneWidget);
      expect(_sheetText('Sin nota'), findsNWidgets(2));
    });
  });

  group('section sheet action matrix', () {
    testWidgets('submitted + folders.evaluate offers only "Evaluar"', (
      tester,
    ) async {
      await _pumpSheet(tester, section: _section(status: _submitted));

      expect(_sheetButtons(tester), ['Evaluar']);
    });

    testWidgets('submitted + both capabilities offers only "Evaluar"', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        section: _section(status: _submitted),
        capabilities: _both,
        requiresUnion: true,
      );

      expect(_sheetButtons(tester), ['Evaluar']);
    });

    testWidgets(
        'preapproved + confirm_union + requiresUnionConfirmation '
        'offers "Confirmar" and "Rechazar" and no "Evaluar"', (tester) async {
      await _pumpSheet(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _both,
        requiresUnion: true,
      );

      expect(_sheetButtons(tester), unorderedEquals(['Confirmar', 'Rechazar']));
    });

    testWidgets('preapproved + only confirm_union still gets the confirm bar', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _union,
        requiresUnion: true,
      );

      expect(_sheetButtons(tester), unorderedEquals(['Confirmar', 'Rechazar']));
    });

    for (final requiresUnion in [true, false]) {
      testWidgets(
          'preapproved + only folders.evaluate (requiresUnion='
          '$requiresUnion) offers only "Evaluar de nuevo"', (tester) async {
        await _pumpSheet(
          tester,
          section: _section(status: _preapproved, earnedPoints: 70),
          requiresUnion: requiresUnion,
        );

        expect(_sheetButtons(tester), ['Evaluar de nuevo']);
      });
    }

    testWidgets(
        'preapproved + confirm_union but no requiresUnionConfirmation '
        'and no folders.evaluate offers nothing', (tester) async {
      await _pumpSheet(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _union,
      );

      expect(_sheetButtons(tester), isEmpty);
    });

    testWidgets(
        'preapproved + both capabilities but no '
        'requiresUnionConfirmation offers "Evaluar de nuevo" instead of the '
        'confirm bar', (tester) async {
      await _pumpSheet(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _both,
      );

      expect(_sheetButtons(tester), ['Evaluar de nuevo']);
    });

    for (final status in [_validated, _rejected]) {
      testWidgets(
          '${status.name} + folders.evaluate offers only '
          '"Reabrir sección"', (tester) async {
        await _pumpSheet(
          tester,
          section: _section(status: status, earnedPoints: 60),
        );

        expect(_sheetButtons(tester), ['Reabrir sección']);
      });

      testWidgets('${status.name} + only confirm_union offers nothing', (
        tester,
      ) async {
        await _pumpSheet(
          tester,
          section: _section(status: status, earnedPoints: 60),
          capabilities: _union,
          requiresUnion: true,
        );

        expect(_sheetButtons(tester), isEmpty);
      });
    }

    testWidgets('a section that was never sent offers nothing', (tester) async {
      await _pumpSheet(tester, section: _section(status: _pendingSection));

      expect(_sheetButtons(tester), isEmpty);
    });

    for (final status in [_submitted, _preapproved, _validated]) {
      testWidgets(
          '${status.name} without capability offers no action and '
          'the notes rows are not tappable', (tester) async {
        await _pumpSheet(
          tester,
          section: _section(status: status, earnedPoints: 60, evidences: [
            evidence('e1', fileName: 'acta.pdf', reviewerNote: 'Nota previa'),
          ]),
          capabilities: const [kSupervisionAppView],
          requiresUnion: true,
        );

        expect(_sheetButtons(tester), isEmpty);
        expect(tester.widget<SacListRow>(_noteRow('acta.pdf')).onTap, isNull);

        await tester.tap(_noteRow('acta.pdf'));
        await tester.pumpAndSettle();
        expect(find.text('Nota de revisión'), findsNothing);
        expect(_sheet, findsOneWidget);
      });
    }

    testWidgets('confirm_union alone does not make the notes tappable', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        section: _section(
          status: _preapproved,
          earnedPoints: 60,
          evidences: [evidence('e1', fileName: 'acta.pdf')],
        ),
        capabilities: _union,
        requiresUnion: true,
      );

      expect(tester.widget<SacListRow>(_noteRow('acta.pdf')).onTap, isNull);
    });

    testWidgets('with folders.evaluate the notes rows are tappable', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        section: _section(evidences: [evidence('e1', fileName: 'acta.pdf')]),
      );

      expect(tester.widget<SacListRow>(_noteRow('acta.pdf')).onTap, isNotNull);
    });

    for (final status in [_submitted, _preapproved, _validated, _rejected]) {
      testWidgets(
          'closed folder: ${status.name} section has no actions and '
          'no tappable notes even with every capability', (tester) async {
        await _pumpSheet(
          tester,
          section: _section(status: status, earnedPoints: 60, evidences: [
            evidence('e1', fileName: 'acta.pdf'),
          ]),
          capabilities: _both,
          status: SupervisionFolderStatus.closed,
          requiresUnion: true,
        );

        expect(_sheetButtons(tester), isEmpty);
        expect(tester.widget<SacListRow>(_noteRow('acta.pdf')).onTap, isNull);
      });
    }
  });

  group('evaluate flow', () {
    testWidgets('the sheet opens empty for a section never evaluated', (
      tester,
    ) async {
      await _pumpSheet(tester);
      await _openEvaluate(tester);

      expect(find.text('Puntos obtenidos'), findsOneWidget);
      expect(find.text('Máx. 100 pts'), findsWidgets);
      final fields =
          tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields.first.controller?.text, '');
      expect(fields.last.controller?.text, '');
    });

    testWidgets('"Evaluar de nuevo" prefills the previous points and notes', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        section: _section(
          status: _preapproved,
          earnedPoints: 70,
          evaluationNotes: 'Revisar tesorería',
        ),
      );
      await _tap(tester, _button('Evaluar de nuevo'));

      final fields =
          tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields.first.controller?.text, '70');
      expect(fields.last.controller?.text, 'Revisar tesorería');
    });

    testWidgets('empty points show an inline error and call nothing', (
      tester,
    ) async {
      final repo = await _pumpSheet(tester);
      await _openEvaluate(tester);

      await _tap(tester, _evaluateConfirm);

      expect(find.text('Escribe un número entre 0 y 100.'), findsOneWidget);
      expect(find.text('Evaluar sección'), findsOneWidget);
      expect(repo.evaluateCalls, isEmpty);
    });

    testWidgets(
        'points above the maximum show an inline error and call '
        'nothing', (tester) async {
      final repo = await _pumpSheet(tester);
      await _openEvaluate(tester);
      await _enterPoints(tester, '101');

      await _tap(tester, _evaluateConfirm);

      expect(find.text('Escribe un número entre 0 y 100.'), findsOneWidget);
      expect(find.text('Evaluar sección'), findsOneWidget);
      expect(repo.evaluateCalls, isEmpty);
    });

    testWidgets('a minus sign cannot be typed', (tester) async {
      await _pumpSheet(tester);
      await _openEvaluate(tester);

      await _enterPoints(tester, '-5');

      final field =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect(field.controller?.text, '5');
    });

    testWidgets('the maximum itself is accepted', (tester) async {
      final repo = await _pumpSheet(tester);

      await _evaluateWith(tester, '100');

      expect(repo.evaluateCalls.single.points, 100);
    });

    testWidgets('zero is accepted', (tester) async {
      final repo = await _pumpSheet(tester);

      await _evaluateWith(tester, '0');

      expect(repo.evaluateCalls.single.points, 0);
      expect(find.text('Sección evaluada'), findsOneWidget);
    });

    testWidgets(
        'valid points call evaluateSection with trimmed notes, close '
        'the sheet and show the toast', (tester) async {
      final repo = await _pumpSheet(tester);

      await _evaluateWith(tester, '85', notes: '  Buen trabajo  ');

      expect(repo.evaluateCalls, hasLength(1));
      final call = repo.evaluateCalls.single;
      expect(call.folderId, 'f1');
      expect(call.sectionId, 's1');
      expect(call.points, 85);
      expect(call.notes, 'Buen trabajo');
      expect(_sheet, findsNothing);
      expect(find.text('Sección evaluada'), findsOneWidget);
    });

    testWidgets('blank notes are sent as no notes', (tester) async {
      final repo = await _pumpSheet(tester);

      await _evaluateWith(tester, '50', notes: '   ');

      expect(repo.evaluateCalls.single.notes, isNull);
    });

    testWidgets(
        'cancelling the evaluate sheet calls nothing and keeps the '
        'section sheet', (tester) async {
      final repo = await _pumpSheet(tester);
      await _openEvaluate(tester);

      await _tap(tester, _button('Cancelar'));

      expect(repo.evaluateCalls, isEmpty);
      expect(find.text('Evaluar sección'), findsNothing);
      expect(_sheetButtons(tester), ['Evaluar']);
    });

    testWidgets('the folder is reloaded after a successful evaluation', (
      tester,
    ) async {
      final repo = await _pumpSheet(tester);
      expect(repo.folderCalls, ['f1']);

      await _evaluateWith(tester, '85');

      expect(repo.folderCalls, ['f1', 'f1']);
    });
  });

  group('confirm union flow', () {
    Future<FakeFoldersRepo> pumpConfirm(
      WidgetTester tester, {
      FakeFoldersRepo? repo,
    }) async {
      final fake = repo ??
          _repoWith(
            sections: [_section(status: _preapproved, earnedPoints: 70)],
            requiresUnion: true,
          );
      return _pumpSheet(tester, repo: fake, capabilities: _union);
    }

    testWidgets(
        'approving calls confirmUnion(approve: true) and closes the '
        'sheet with a toast', (tester) async {
      final repo = await pumpConfirm(tester);

      await _tap(tester, _button('Confirmar'));
      expect(find.text('Confirmar sección'), findsOneWidget);
      expect(repo.confirmCalls, isEmpty);
      await _tap(tester, _button('Confirmar').last);

      expect(repo.confirmCalls, hasLength(1));
      final call = repo.confirmCalls.single;
      expect(call.folderId, 'f1');
      expect(call.sectionId, 's1');
      expect(call.approve, isTrue);
      expect(call.notes, isNull);
      expect(_sheet, findsNothing);
      expect(find.text('Sección confirmada'), findsOneWidget);
    });

    testWidgets('approving sends the trimmed optional comment', (tester) async {
      final repo = await pumpConfirm(tester);

      await _tap(tester, _button('Confirmar'));
      await tester.enterText(find.byType(TextFormField), '  De acuerdo  ');
      await tester.pump();
      await _tap(tester, _button('Confirmar').last);

      expect(repo.confirmCalls.single.approve, isTrue);
      expect(repo.confirmCalls.single.notes, 'De acuerdo');
    });

    testWidgets('rejecting calls confirmUnion(approve: false, notes)', (
      tester,
    ) async {
      final repo = await pumpConfirm(tester);

      await _tap(tester, _button('Rechazar'));
      expect(find.text('Rechazar sección'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), ' Falta evidencia ');
      await tester.pump();
      await _tap(tester, _button('Rechazar').last);

      expect(repo.confirmCalls, hasLength(1));
      final call = repo.confirmCalls.single;
      expect(call.approve, isFalse);
      expect(call.notes, 'Falta evidencia');
      expect(_sheet, findsNothing);
      expect(find.text('Sección rechazada'), findsOneWidget);
    });

    testWidgets('cancelling the decision sheet calls nothing', (tester) async {
      final repo = await pumpConfirm(tester);

      await _tap(tester, _button('Rechazar'));
      await _tap(tester, _button('Cancelar'));

      expect(repo.confirmCalls, isEmpty);
      expect(_sheetButtons(tester), unorderedEquals(['Confirmar', 'Rechazar']));
    });

    testWidgets('the decision sheet names the section', (tester) async {
      await pumpConfirm(tester);

      await _tap(tester, _button('Confirmar'));

      // Header of the section sheet and subtitle of the decision sheet.
      expect(_sheetText('Sección s1'), findsOneWidget);
      expect(find.text('Sección s1'), findsNWidgets(3));
    });
  });

  group('reopen flow', () {
    testWidgets('confirming the dialog calls reopenSection', (tester) async {
      final repo = await _pumpSheet(
        tester,
        section: _section(status: _validated, earnedPoints: 80),
      );

      await _tap(tester, _button('Reabrir sección'));
      expect(find.text('¿Reabrir esta sección?'), findsOneWidget);
      expect(repo.reopenCalls, isEmpty);
      await _tap(tester, _dialogButton('Reabrir sección'));

      expect(repo.reopenCalls, [(folderId: 'f1', sectionId: 's1')]);
      expect(_sheet, findsNothing);
      expect(find.text('Sección reabierta'), findsOneWidget);
    });

    testWidgets('cancelling the dialog does not reopen', (tester) async {
      final repo = await _pumpSheet(
        tester,
        section: _section(status: _rejected, earnedPoints: 10),
      );

      await _tap(tester, _button('Reabrir sección'));
      await _tap(tester, _dialogButton('Cancelar'));

      expect(repo.reopenCalls, isEmpty);
      expect(_sheet, findsOneWidget);
      expect(find.text('Sección reabierta'), findsNothing);
    });

    testWidgets('a failure shows the error inline and keeps the sheet', (
      tester,
    ) async {
      final repo = _repoWith(
        sections: [_section(status: _validated, earnedPoints: 80)],
      )..onReopen = () async => Left(codedFailure('X', 'No se pudo reabrir'));
      await _pumpSheet(tester, repo: repo);

      await _tap(tester, _button('Reabrir sección'));
      await _tap(tester, _dialogButton('Reabrir sección'));

      expect(_sheetText('No se pudo reabrir'), findsOneWidget);
      expect(_sheetButtons(tester), ['Reabrir sección']);
    });
  });

  group('reviewer notes', () {
    FakeFoldersRepo repoWithNote() => _repoWith(sections: [
          _section(evidences: [
            evidence('e1', fileName: 'acta.pdf', reviewerNote: 'Falta firma'),
          ]),
        ]);

    testWidgets(
        'tapping an evidence opens the decision sheet prefilled with '
        'the existing note', (tester) async {
      await _pumpSheet(tester, repo: repoWithNote());

      await _tap(tester, _noteRow('acta.pdf'));

      expect(find.text('Nota de revisión'), findsOneWidget);
      expect(find.text('Nota para el club'), findsOneWidget);
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, 'Falta firma');
    });

    testWidgets('an evidence without note opens an empty field', (
      tester,
    ) async {
      final repo = _repoWith(sections: [
        _section(evidences: [evidence('e1', fileName: 'acta.pdf')]),
      ]);
      await _pumpSheet(tester, repo: repo);

      await _tap(tester, _noteRow('acta.pdf'));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, '');
    });

    testWidgets(
        'saving calls saveReviewerNote and the section sheet stays '
        'open', (tester) async {
      final repo = await _pumpSheet(tester, repo: repoWithNote());

      await _tap(tester, _noteRow('acta.pdf'));
      await tester.enterText(find.byType(TextFormField), '  Firma legible  ');
      await tester.pump();
      await _tap(tester, _button('Guardar'));

      expect(repo.noteCalls, [(evidenceId: 'e1', note: 'Firma legible')]);
      expect(find.text('Nota de revisión'), findsNothing);
      expect(_sheet, findsOneWidget);
      expect(_sheetText('Sección s1'), findsOneWidget);
      expect(_sheetButtons(tester), ['Evaluar']);
    });

    testWidgets('saving a blank note clears it', (tester) async {
      final repo = await _pumpSheet(tester, repo: repoWithNote());

      await _tap(tester, _noteRow('acta.pdf'));
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pump();
      await _tap(tester, _button('Guardar'));

      expect(repo.noteCalls, [(evidenceId: 'e1', note: null)]);
    });

    testWidgets('cancelling does not save', (tester) async {
      final repo = await _pumpSheet(tester, repo: repoWithNote());

      await _tap(tester, _noteRow('acta.pdf'));
      await _tap(tester, _button('Cancelar'));

      expect(repo.noteCalls, isEmpty);
      expect(_sheet, findsOneWidget);
    });

    testWidgets(
        'a failure shows the error inline and the note can be edited '
        'again', (tester) async {
      final repo = repoWithNote()
        ..onNote = () async => Left(codedFailure('X', 'Nota rechazada'));
      await _pumpSheet(tester, repo: repo);

      await _tap(tester, _noteRow('acta.pdf'));
      await _tap(tester, _button('Guardar'));

      expect(repo.noteCalls, hasLength(1));
      expect(_sheetText('Nota rechazada'), findsOneWidget);
      expect(_sheet, findsOneWidget);
      expect(tester.widget<SacListRow>(_noteRow('acta.pdf')).onTap, isNotNull);

      await _tap(tester, _noteRow('acta.pdf'));
      expect(find.text('Nota de revisión'), findsOneWidget);
    });

    testWidgets('a later successful save clears the inline error', (
      tester,
    ) async {
      var fail = true;
      final repo = repoWithNote()
        ..onNote = () async {
          if (fail) {
            fail = false;
            return Left(codedFailure('X', 'Nota rechazada'));
          }
          return const Right(unit);
        };
      await _pumpSheet(tester, repo: repo);

      await _tap(tester, _noteRow('acta.pdf'));
      await _tap(tester, _button('Guardar'));
      expect(_sheetText('Nota rechazada'), findsOneWidget);

      await _tap(tester, _noteRow('acta.pdf'));
      await _tap(tester, _button('Guardar'));

      expect(repo.noteCalls, hasLength(2));
      expect(_sheetText('Nota rechazada'), findsNothing);
    });
  });

  group('error mapping', () {
    const cases = {
      'ANNUAL_FOLDER_UNION_ROLE_REQUIRED':
          'Solo la Unión puede confirmar esta sección.',
      'ANNUAL_FOLDER_EARNED_POINTS_EXCEED_MAX':
          'Los puntos superan el máximo de la sección.',
      'ANNUAL_FOLDER_EVIDENCE_TERRITORY_DENIED':
          'Esta carpeta está fuera de tu territorio.',
      'ANNUAL_FOLDER_FOLDER_ACCESS_DENIED':
          'Esta carpeta está fuera de tu territorio.',
      'ANNUAL_FOLDER_STATUS_INVALID_FOR_EVALUATE':
          'La sección cambió de estado. Revisa de nuevo.',
      'ANNUAL_FOLDER_STATUS_INVALID_FOR_REOPEN':
          'La sección cambió de estado. Revisa de nuevo.',
      'ANNUAL_FOLDER_SECTION_TERMINAL':
          'La sección cambió de estado. Revisa de nuevo.',
      'ANNUAL_FOLDER_SECTION_NOT_PREAPPROVED':
          'La sección cambió de estado. Revisa de nuevo.',
      'ANNUAL_FOLDER_STATUS_CONFLICT':
          'La sección cambió de estado. Revisa de nuevo.',
    };

    for (final entry in cases.entries) {
      testWidgets(
          '${entry.key} shows its own text inline and keeps the sheet '
          'usable', (tester) async {
        final repo = _repoWith()
          ..onEvaluate = () async => Left(codedFailure(entry.key));
        await _pumpSheet(tester, repo: repo);

        await _evaluateWith(tester, '50');

        expect(repo.evaluateCalls, hasLength(1));
        expect(_sheetText(entry.value), findsOneWidget);
        // The server message is not what the user reads.
        expect(find.text('server says no'), findsNothing);
        expect(_sheet, findsOneWidget);
        expect(_sheetButtons(tester), ['Evaluar']);
        final action = tester.widget<SacButton>(_button('Evaluar'));
        expect(action.isLoading, isFalse);
        expect(action.onPressed, isNotNull);
        // No success toast.
        expect(find.text('Sección evaluada'), findsNothing);
      });
    }

    testWidgets('an unknown code shows the server message inline', (
      tester,
    ) async {
      final repo = _repoWith()
        ..onEvaluate =
            () async => Left(codedFailure('SOMETHING_NEW', 'Hubo un problema'));
      await _pumpSheet(tester, repo: repo);

      await _evaluateWith(tester, '50');

      expect(_sheetText('Hubo un problema'), findsOneWidget);
      expect(_sheet, findsOneWidget);
    });

    testWidgets('a stale code reloads the folder', (tester) async {
      final repo = _repoWith()
        ..onEvaluate =
            () async => Left(codedFailure('ANNUAL_FOLDER_SECTION_TERMINAL'));
      await _pumpSheet(tester, repo: repo);
      expect(repo.folderCalls, ['f1']);

      await _evaluateWith(tester, '50');

      expect(repo.folderCalls, ['f1', 'f1']);
    });

    testWidgets('a non stale code does not reload the folder', (tester) async {
      final repo = _repoWith()
        ..onEvaluate = () async => Left(codedFailure('SOMETHING_NEW'));
      await _pumpSheet(tester, repo: repo);

      await _evaluateWith(tester, '50');

      expect(repo.folderCalls, ['f1']);
    });

    testWidgets('the action works again after an error', (tester) async {
      var fail = true;
      final repo = _repoWith()
        ..onEvaluate = () async {
          if (fail) {
            fail = false;
            return Left(codedFailure('ANNUAL_FOLDER_UNION_ROLE_REQUIRED'));
          }
          return const Right(unit);
        };
      await _pumpSheet(tester, repo: repo);

      await _evaluateWith(tester, '50');
      expect(_sheetText('Solo la Unión puede confirmar esta sección.'),
          findsOneWidget);

      await _evaluateWith(tester, '60');

      expect(repo.evaluateCalls.map((c) => c.points), [50, 60]);
      expect(_sheet, findsNothing);
      expect(find.text('Sección evaluada'), findsOneWidget);
    });

    testWidgets('the error is cleared when the next attempt starts', (
      tester,
    ) async {
      final gate = Completer<ActionResult>();
      var first = true;
      final repo = _repoWith()
        ..onEvaluate = () {
          if (first) {
            first = false;
            return Future.value(Left(codedFailure('SOMETHING_NEW', 'Falló')));
          }
          return gate.future;
        };
      await _pumpSheet(tester, repo: repo);

      await _evaluateWith(tester, '50');
      expect(_sheetText('Falló'), findsOneWidget);

      await _openEvaluate(tester);
      await _enterPoints(tester, '60');
      await tester.tap(_evaluateConfirm);
      await tester.pump();
      await tester.pump();

      expect(_sheetText('Falló'), findsNothing);
      expect(tester.widget<SacButton>(_button('Evaluar')).isLoading, isTrue);

      gate.complete(const Right(unit));
      await tester.pumpAndSettle();
    });

    testWidgets('a confirm error from the Union shows inline in the sheet', (
      tester,
    ) async {
      final repo = _repoWith(
        sections: [_section(status: _preapproved, earnedPoints: 70)],
        requiresUnion: true,
      )..onConfirm =
          () async => Left(codedFailure('ANNUAL_FOLDER_UNION_ROLE_REQUIRED'));
      await _pumpSheet(tester, repo: repo, capabilities: _union);

      await _tap(tester, _button('Confirmar'));
      await _tap(tester, _button('Confirmar').last);

      expect(_sheetText('Solo la Unión puede confirmar esta sección.'),
          findsOneWidget);
      expect(_sheetButtons(tester), unorderedEquals(['Confirmar', 'Rechazar']));
    });

    // BUG (low): `key?.tr() ?? result.errorMessage ?? generic` in
    // supervision_folder_detail_view.dart:390 only falls back on null, so a
    // failure with an empty message sets an empty inline error. Failing
    // assertion: _sheetText('Ocurrió un error. Inténtalo de nuevo.') -> 0.
    testWidgets(
        'a failure with a blank message falls back to the generic '
        'error', (tester) async {
      final repo = _repoWith()
        ..onEvaluate = () async => const Left(ServerFailure(message: ''));
      await _pumpSheet(tester, repo: repo);

      await _evaluateWith(tester, '50');

      expect(
          _sheetText('Ocurrió un error. Inténtalo de nuevo.'), findsOneWidget);
    });
  });

  group('layout robustness', () {
    const narrow = Size(320, 1600);

    SupervisionFolderSection heavySectionOf({
      bool withFiles = false,
      bool withFacts = false,
    }) =>
        section(
          's1',
          name: 'Sección de tesorería y finanzas del club de la asociación',
          status: _submitted,
          maxPoints: 100,
          earnedPoints: withFacts ? 70 : null,
          evaluationNotes: withFacts
              ? 'Falta documentar los ingresos del segundo semestre'
              : null,
          lfApproverName: withFacts ? 'Marta Gutiérrez de la Cruz' : null,
          lfApprovedAt: withFacts ? DateTime(2026, 4, 2) : null,
          unionApproverName: withFacts ? 'Luis Alberto Pérez Salazar' : null,
          description:
              'Presenta el informe financiero anual con todos los comprobantes '
              'de ingresos y egresos firmados por el tesorero.',
          evidences: withFiles
              ? [
                  evidence('e1',
                      fileName:
                          'informe-financiero-anual-2026-version-final.pdf',
                      reviewerNote:
                          'Falta la firma del tesorero en la tercera página'),
                  evidence('e2', fileName: 'comprobantes.pdf'),
                ]
              : const [],
        );
    final heavySection = heavySectionOf();

    testWidgets('page at 320 wide and text scale 2.0 does not overflow', (
      tester,
    ) async {
      final repo = _repoWith(
        localFieldName: '',
        templateName: '',
        sections: [
          heavySection,
          section('s2',
              name: 'Misiones',
              status: _preapproved,
              earnedPoints: 70,
              maxPoints: 100),
        ],
      );
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);

      expectNoLayoutException(tester);
      expect(find.byType(SacListRow), findsNWidgets(2));
      expect(_button('Cerrar carpeta'), findsOneWidget);
    });

    testWidgets('page with every summary row at 320 wide does not overflow', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onFolder = (_) async => Right(folderDetail(
              submittedAt: DateTime(2026, 3, 14),
              sections: [heavySection],
            ));
      await _pump(tester, repo: repo, size: narrow);

      expectNoLayoutException(tester);
      expect(_row('Campo local'), findsOneWidget);
      expect(_row('Plantilla'), findsOneWidget);
      expect(_row('Enviada'), findsOneWidget);
    });

    // SacValueRow (sac_value_row.dart:23) does not let its label flex: the
    // longer labels ("Campo local", "Plantilla") overflow the row at 320 wide
    // and scale 2.0 by 101 and 40 px under the Ahem font (one em per glyph).
    // Real fonts are narrower and may fit; translations with longer labels
    // may not.
    testWidgets(
        'page with the optional summary rows at 320 wide and text '
        'scale 2.0 does not overflow', (tester) async {
      final repo = _repoWith(sections: [heavySection]);
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);

      expectNoLayoutException(tester);
    });

    testWidgets(
        'section sheet at 320 wide and text scale 2.0 does not '
        'overflow', (tester) async {
      final repo = _repoWith(
        localFieldName: '',
        templateName: '',
        sections: [heavySection],
      );
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);
      await tester.tap(find.byType(SacListRow).first);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
      expect(_sheet, findsOneWidget);
      expect(_sheetButtons(tester), ['Evaluar']);
    });

    testWidgets(
        'section sheet with evaluation facts at 320 wide and text scale 2.0 '
        'does not overflow', (tester) async {
      final repo = _repoWith(
        localFieldName: '',
        templateName: '',
        sections: [heavySectionOf(withFacts: true)],
      );
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);
      await tester.tap(find.byType(SacListRow).first);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
      expect(_row('Evaluó', inSheet: true), findsOneWidget);
    });

    // EvidenceFileGallery._FileTile (coordinator/presentation/widgets/
    // evidence_file_gallery.dart:183) lays a 28 px icon plus a two-line label
    // inside a fixed 1:1 grid cell (72 x 72 at 320 wide, 56 px inside its
    // padding). At scale 2.0 the label alone is taller than the cell: the
    // Column overflows by 26 px on the bottom (Ahem; real fonts overflow too
    // once the name wraps to two lines).
    testWidgets(
        'section sheet with file evidences at 320 wide and text scale 2.0 '
        'does not overflow', (tester) async {
      final repo = _repoWith(
        localFieldName: '',
        templateName: '',
        sections: [heavySectionOf(withFiles: true)],
      );
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);
      await tester.tap(find.byType(SacListRow).first);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
    });

    testWidgets(
        'section sheet with file evidences at 320 wide does not overflow',
        (tester) async {
      final repo = _repoWith(
        localFieldName: '',
        templateName: '',
        sections: [heavySectionOf(withFiles: true)],
      );
      await _pump(tester, repo: repo, size: narrow);
      await tester.tap(find.byType(SacListRow).first);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
      expect(_sheetText('NOTAS DE REVISIÓN'), findsOneWidget);
    });

    testWidgets(
        'Union confirm bar at 320 wide and text scale 2.0 does not '
        'overflow', (tester) async {
      final repo = _repoWith(
        sections: [_section(status: _preapproved, earnedPoints: 70)],
        requiresUnion: true,
        localFieldName: '',
        templateName: '',
      );
      await _pump(
        tester,
        repo: repo,
        capabilities: _union,
        size: narrow,
        textScale: 2.0,
      );
      await tester.tap(find.byType(SacListRow).first);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
      expect(_sheetButtons(tester), unorderedEquals(['Confirmar', 'Rechazar']));
    });

    testWidgets(
        'evaluate sheet at 320 wide and text scale 2.0 does not '
        'overflow', (tester) async {
      final repo = _repoWith(
        localFieldName: '',
        templateName: '',
        sections: [heavySection],
      );
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);
      await tester.tap(find.byType(SacListRow).first);
      await tester.pumpAndSettle();
      await tester.tap(_button('Evaluar'));
      await tester.pumpAndSettle();
      await _enterPoints(tester, '101');
      await tester.tap(_evaluateConfirm);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
      expect(find.text('Evaluar sección'), findsOneWidget);
      expect(find.text('Escribe un número entre 0 y 100.'), findsOneWidget);
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
        'Secretaría': 'Por evaluar',
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
  });
}
