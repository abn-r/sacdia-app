/// Widget tests for one section of an annual folder on its own screen:
/// content (description, evaluation facts, evidences, review notes), the fixed
/// footer action per capability and status, the evaluation, the Union
/// confirmation, the reopening and the reviewer notes.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
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
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_folder_detail_view.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_folder_section_view.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_quote.dart';

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

/// Pumps the folder and opens the screen of section `s1` through its row,
/// the way a user gets there.
Future<FakeFoldersRepo> _pumpSection(
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
  await pumpFoldersApp(
    tester,
    home: const SupervisionFolderDetailView(folderId: 'f1'),
    repo: fake,
    capabilities: capabilities,
    size: size,
    textScale: textScale,
    sectionBuilder: (folderId, sectionId) => SupervisionFolderSectionView(
      folderId: folderId,
      sectionId: sectionId,
    ),
  );
  await tester.tap(find.byType(SacListRow).first);
  await tester.pumpAndSettle();
  return fake;
}

SupervisionFolderSection _section({
  SupervisionSectionStatus status = _submitted,
  int? earnedPoints,
  String? evaluationNotes,
  String? lfApproverName,
  DateTime? lfApprovedAt,
  List<SupervisionFolderEvidence> evidences = const [],
}) =>
    section(
      's1',
      status: status,
      earnedPoints: earnedPoints,
      evaluationNotes: evaluationNotes,
      lfApproverName: lfApproverName,
      lfApprovedAt: lfApprovedAt,
      evidences: evidences,
    );

final Finder _screen = find.byType(SupervisionFolderSectionView);

Finder _onScreen(Finder finder) =>
    find.descendant(of: _screen, matching: finder);

/// Inside the open bottom sheet (the evaluate sheet).
Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(BottomSheet).last, matching: finder);

Finder _sheetText(String text) => _onScreen(find.text(text));

/// Whether the section screen is the visible route.
bool _screenOpen() => _screen.evaluate().isNotEmpty;

/// Labels of every [SacButton] of the section screen (its fixed footer).
List<String> _footerButtons(WidgetTester tester) => tester
    .widgetList<SacButton>(_onScreen(find.byType(SacButton)))
    .map((b) => b.text)
    .toList();

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

Finder _noteRow(String fileName) => find.widgetWithText(SacListRow, fileName);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The big points field of the evaluate sheet (the first text field).
Future<void> _enterPoints(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump();
}

/// Opens the evaluate sheet from the footer.
Future<void> _openEvaluate(WidgetTester tester) async {
  await _tap(tester, _button('Evaluar sección'));
  // The sheet title and the footer button.
  expect(find.text('Evaluar sección'), findsNWidgets(2));
}

/// Primary of the evaluate sheet.
Finder get _evaluateConfirm => _button('Guardar evaluación');

Future<void> _evaluateWith(
  WidgetTester tester,
  String points, {
  String? notes,
}) async {
  await _openEvaluate(tester);
  await _enterPoints(tester, points);
  if (notes != null) {
    await tester.enterText(find.byType(TextField).last, notes);
    await tester.pump();
  }
  await _tap(tester, _evaluateConfirm);
}

void main() {
  setUpAll(initSupervisionViewTests);

  group('navigation and states', () {
    testWidgets('the folder row opens the section on its own screen', (
      tester,
    ) async {
      await _pumpSection(tester);

      expect(_screenOpen(), isTrue);
      // Top bar: the section name, then "club · status".
      expect(_sheetText('Sección s1'), findsOneWidget);
      expect(_sheetText('Club Orión · Por evaluar'), findsOneWidget);
    });

    testWidgets('shows the skeleton while the folder loads', (tester) async {
      final gate = Completer<FolderResult>();
      final repo = FakeFoldersRepo()..onFolder = (_) => gate.future;
      await pumpFoldersApp(
        tester,
        home: const SupervisionFolderSectionView(
          folderId: 'f1',
          sectionId: 's1',
        ),
        repo: repo,
        settle: false,
      );

      expect(find.byType(SacSkeletonList), findsOneWidget);
      gate.complete(Right(folderDetail()));
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Sección s1'), findsOneWidget);
    });

    testWidgets('an error shows the state and retry reloads the folder', (
      tester,
    ) async {
      final repo = FakeFoldersRepo();
      repo.onFolder = (_) async => repo.folderCalls.length == 1
          ? const Left(kBoom)
          : Right(folderDetail());
      await pumpFoldersApp(
        tester,
        home: const SupervisionFolderSectionView(
          folderId: 'f1',
          sectionId: 's1',
        ),
        repo: repo,
      );

      expect(find.byType(SacErrorState), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.folderCalls, ['f1', 'f1']);
      expect(find.text('Sección s1'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView', (tester) async {
      final repo = FakeFoldersRepo()
        ..onFolder =
            (_) async => const Left(AuthFailure(message: 'nope', code: 403));
      await pumpFoldersApp(
        tester,
        home: const SupervisionFolderSectionView(
          folderId: 'f1',
          sectionId: 's1',
        ),
        repo: repo,
      );

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('a section that is not in the folder says so', (tester) async {
      await pumpFoldersApp(
        tester,
        home: const SupervisionFolderSectionView(
          folderId: 'f1',
          sectionId: 'missing',
        ),
        repo: FakeFoldersRepo(),
      );

      expect(find.text('No se encontró la sección'), findsOneWidget);
      expect(find.byType(SacFrostedFooter), findsNothing);
    });
  });

  group('section content', () {
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
      await _pumpSection(tester, repo: repo);

      final date = intl.DateFormat.yMMMd('es').format(when);
      expect(_sheetText('Entrega el acta anual firmada'), findsOneWidget);
      expect(_row('Puntos', value: '80 de 100 pts'), findsOneWidget);
      expect(_row('Notas', value: 'Todo en orden'), findsOneWidget);
      expect(_row('Evaluó', value: 'Marta Ruiz'), findsOneWidget);
      expect(_row('Fecha', value: date), findsOneWidget);
      expect(_row('Unión', value: 'Luis Pérez'), findsOneWidget);
      expect(_row('Confirmada', value: date), findsOneWidget);
      expect(_sheetText('EVIDENCIAS'), findsOneWidget);
      expect(_sheetText('NOTAS DE REVISIÓN'), findsOneWidget);
      // File tile of the gallery plus the row of the notes list.
      expect(_sheetText('acta.pdf'), findsNWidgets(2));
    });

    testWidgets('a section never evaluated has no evaluation group', (
      tester,
    ) async {
      await _pumpSection(tester);

      expect(_sheetText('EVALUACIÓN'), findsNothing);
      expect(_row('Evaluó'), findsNothing);
      expect(_row('Unión'), findsNothing);
      expect(_row('Confirmada'), findsNothing);
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
      await _pumpSection(tester, repo: repo);

      expect(_sheetText('Falta firma'), findsOneWidget);
      expect(_sheetText('Sin nota'), findsNWidgets(2));
    });
  });

  group('footer action matrix', () {
    testWidgets('submitted + folders.evaluate offers only "Evaluar sección"', (
      tester,
    ) async {
      await _pumpSection(tester, section: _section(status: _submitted));

      expect(_footerButtons(tester), ['Evaluar sección']);
    });

    testWidgets('submitted + both capabilities offers only "Evaluar sección"', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: _section(status: _submitted),
        capabilities: _both,
        requiresUnion: true,
      );

      expect(_footerButtons(tester), ['Evaluar sección']);
    });

    testWidgets(
        'preapproved + confirm_union + requiresUnionConfirmation '
        'offers "Confirmar 70 pts" and "Rechazar sección" and no "Evaluar"',
        (tester) async {
      await _pumpSection(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _both,
        requiresUnion: true,
      );

      expect(_footerButtons(tester),
          unorderedEquals(['Confirmar 70 pts', 'Rechazar sección']));
    });

    testWidgets('preapproved + only confirm_union still gets the confirm bar', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _union,
        requiresUnion: true,
      );

      expect(_footerButtons(tester),
          unorderedEquals(['Confirmar 70 pts', 'Rechazar sección']));
    });

    for (final requiresUnion in [true, false]) {
      testWidgets(
          'preapproved + only folders.evaluate (requiresUnion='
          '$requiresUnion) offers only "Evaluar de nuevo"', (tester) async {
        await _pumpSection(
          tester,
          section: _section(status: _preapproved, earnedPoints: 70),
          requiresUnion: requiresUnion,
        );

        expect(_footerButtons(tester), ['Evaluar de nuevo']);
      });
    }

    testWidgets(
        'preapproved + confirm_union but no requiresUnionConfirmation '
        'and no folders.evaluate offers nothing', (tester) async {
      await _pumpSection(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _union,
      );

      expect(_footerButtons(tester), isEmpty);
    });

    testWidgets(
        'preapproved + both capabilities but no '
        'requiresUnionConfirmation offers "Evaluar de nuevo" instead of the '
        'confirm bar', (tester) async {
      await _pumpSection(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _both,
      );

      expect(_footerButtons(tester), ['Evaluar de nuevo']);
    });

    for (final status in [_validated, _rejected]) {
      testWidgets(
          '${status.name} + folders.evaluate offers only '
          '"Reabrir sección"', (tester) async {
        await _pumpSection(
          tester,
          section: _section(status: status, earnedPoints: 60),
        );

        expect(_footerButtons(tester), ['Reabrir sección']);
      });

      testWidgets('${status.name} + only confirm_union offers nothing', (
        tester,
      ) async {
        await _pumpSection(
          tester,
          section: _section(status: status, earnedPoints: 60),
          capabilities: _union,
          requiresUnion: true,
        );

        expect(_footerButtons(tester), isEmpty);
      });
    }

    testWidgets('a section that was never sent offers nothing', (tester) async {
      await _pumpSection(tester, section: _section(status: _pendingSection));

      expect(_footerButtons(tester), isEmpty);
    });

    for (final status in [_submitted, _preapproved, _validated]) {
      testWidgets(
          '${status.name} without capability offers no action and '
          'the notes rows are not tappable', (tester) async {
        await _pumpSection(
          tester,
          section: _section(status: status, earnedPoints: 60, evidences: [
            evidence('e1', fileName: 'acta.pdf', reviewerNote: 'Nota previa'),
          ]),
          capabilities: const [kSupervisionAppView],
          requiresUnion: true,
        );

        expect(_footerButtons(tester), isEmpty);
        expect(tester.widget<SacListRow>(_noteRow('acta.pdf')).onTap, isNull);

        await tester.tap(_noteRow('acta.pdf'));
        await tester.pumpAndSettle();
        expect(find.text('Nota de revisión'), findsNothing);
        expect(_screenOpen(), isTrue);
      });
    }

    testWidgets('confirm_union alone does not make the notes tappable', (
      tester,
    ) async {
      await _pumpSection(
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
      await _pumpSection(
        tester,
        section: _section(evidences: [evidence('e1', fileName: 'acta.pdf')]),
      );

      expect(tester.widget<SacListRow>(_noteRow('acta.pdf')).onTap, isNotNull);
    });

    for (final status in [_submitted, _preapproved, _validated, _rejected]) {
      testWidgets(
          'closed folder: ${status.name} section has no actions and '
          'no tappable notes even with every capability', (tester) async {
        await _pumpSection(
          tester,
          section: _section(status: status, earnedPoints: 60, evidences: [
            evidence('e1', fileName: 'acta.pdf'),
          ]),
          capabilities: _both,
          status: SupervisionFolderStatus.closed,
          requiresUnion: true,
        );

        expect(_footerButtons(tester), isEmpty);
        expect(tester.widget<SacListRow>(_noteRow('acta.pdf')).onTap, isNull);
      });
    }
  });

  group('evaluate flow', () {
    testWidgets('the sheet opens empty for a section never evaluated', (
      tester,
    ) async {
      await _pumpSection(tester);
      await _openEvaluate(tester);

      expect(find.text('Puntos obtenidos'), findsOneWidget);
      expect(find.text('de 100 pts'), findsOneWidget);
      expect(find.text('Sección s1 · máximo 100 pts'), findsOneWidget);
      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields.first.controller?.text, '');
      expect(fields.last.controller?.text, '');
    });

    testWidgets('"Evaluar de nuevo" prefills the previous points and notes', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: _section(
          status: _preapproved,
          earnedPoints: 70,
          evaluationNotes: 'Revisar tesorería',
        ),
      );
      await _tap(tester, _button('Evaluar de nuevo'));

      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields.first.controller?.text, '70');
      expect(fields.last.controller?.text, 'Revisar tesorería');
    });

    testWidgets('empty points show an inline error and call nothing', (
      tester,
    ) async {
      final repo = await _pumpSection(tester);
      await _openEvaluate(tester);

      await _tap(tester, _evaluateConfirm);

      expect(find.text('Escribe un número entre 0 y 100.'), findsOneWidget);
      expect(find.text('Evaluar sección'), findsNWidgets(2));
      expect(repo.evaluateCalls, isEmpty);
    });

    testWidgets(
        'points above the maximum show an inline error and call '
        'nothing', (tester) async {
      final repo = await _pumpSection(tester);
      await _openEvaluate(tester);
      await _enterPoints(tester, '101');

      await _tap(tester, _evaluateConfirm);

      expect(find.text('Escribe un número entre 0 y 100.'), findsOneWidget);
      expect(find.text('Evaluar sección'), findsNWidgets(2));
      expect(repo.evaluateCalls, isEmpty);
    });

    testWidgets('quick values fill the field: 0, half and the maximum', (
      tester,
    ) async {
      final repo = await _pumpSection(tester);
      await _openEvaluate(tester);

      for (final value in ['0', '50', '100']) {
        await tester.tap(_inSheet(find.text(value)));
        await tester.pump();
        final field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.controller?.text, value);
      }
      await _tap(tester, _evaluateConfirm);

      expect(repo.evaluateCalls.single.points, 100);
    });

    testWidgets('a quick value clears a previous validation error', (
      tester,
    ) async {
      await _pumpSection(tester);
      await _openEvaluate(tester);
      await _enterPoints(tester, '101');
      await _tap(tester, _evaluateConfirm);
      expect(find.text('Escribe un número entre 0 y 100.'), findsOneWidget);

      await tester.tap(_inSheet(find.text('50')));
      await tester.pump();

      expect(find.text('Escribe un número entre 0 y 100.'), findsNothing);
    });

    testWidgets('a minus sign cannot be typed', (tester) async {
      await _pumpSection(tester);
      await _openEvaluate(tester);

      await _enterPoints(tester, '-5');

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, '5');
    });

    testWidgets('the maximum itself is accepted', (tester) async {
      final repo = await _pumpSection(tester);

      await _evaluateWith(tester, '100');

      expect(repo.evaluateCalls.single.points, 100);
    });

    testWidgets('zero is accepted', (tester) async {
      final repo = await _pumpSection(tester);

      await _evaluateWith(tester, '0');

      expect(repo.evaluateCalls.single.points, 0);
      expect(find.text('Sección evaluada'), findsOneWidget);
    });

    testWidgets(
        'valid points call evaluateSection with trimmed notes, close '
        'the sheet and show the toast', (tester) async {
      final repo = await _pumpSection(tester);

      await _evaluateWith(tester, '85', notes: '  Buen trabajo  ');

      expect(repo.evaluateCalls, hasLength(1));
      final call = repo.evaluateCalls.single;
      expect(call.folderId, 'f1');
      expect(call.sectionId, 's1');
      expect(call.points, 85);
      expect(call.notes, 'Buen trabajo');
      expect(_screenOpen(), isFalse);
      expect(find.text('Sección evaluada'), findsOneWidget);
    });

    testWidgets('blank notes are sent as no notes', (tester) async {
      final repo = await _pumpSection(tester);

      await _evaluateWith(tester, '50', notes: '   ');

      expect(repo.evaluateCalls.single.notes, isNull);
    });

    testWidgets(
        'cancelling the evaluate sheet calls nothing and keeps the '
        'section sheet', (tester) async {
      final repo = await _pumpSection(tester);
      await _openEvaluate(tester);

      await _tap(tester, _button('Cancelar'));

      expect(repo.evaluateCalls, isEmpty);
      // Only the footer button is left.
      expect(find.text('Evaluar sección'), findsOneWidget);
      expect(_footerButtons(tester), ['Evaluar sección']);
    });

    testWidgets('the folder is reloaded after a successful evaluation', (
      tester,
    ) async {
      final repo = await _pumpSection(tester);
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
      return _pumpSection(tester, repo: fake, capabilities: _union);
    }

    testWidgets(
        'approving calls confirmUnion(approve: true) and closes the '
        'sheet with a toast', (tester) async {
      final repo = await pumpConfirm(tester);

      await _tap(tester, _button('Confirmar 70 pts'));
      expect(find.text('Confirmar sección'), findsOneWidget);
      expect(repo.confirmCalls, isEmpty);
      await _tap(tester, _button('Confirmar'));

      expect(repo.confirmCalls, hasLength(1));
      final call = repo.confirmCalls.single;
      expect(call.folderId, 'f1');
      expect(call.sectionId, 's1');
      expect(call.approve, isTrue);
      expect(call.notes, isNull);
      expect(_screenOpen(), isFalse);
      expect(find.text('Sección confirmada'), findsOneWidget);
    });

    testWidgets('approving sends the trimmed optional comment', (tester) async {
      final repo = await pumpConfirm(tester);

      await _tap(tester, _button('Confirmar 70 pts'));
      await tester.enterText(find.byType(TextFormField), '  De acuerdo  ');
      await tester.pump();
      await _tap(tester, _button('Confirmar'));

      expect(repo.confirmCalls.single.approve, isTrue);
      expect(repo.confirmCalls.single.notes, 'De acuerdo');
    });

    testWidgets('rejecting calls confirmUnion(approve: false, notes)', (
      tester,
    ) async {
      final repo = await pumpConfirm(tester);

      await _tap(tester, _button('Rechazar sección'));
      // The footer text button and the title of the decision sheet.
      expect(find.text('Rechazar sección'), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField), ' Falta evidencia ');
      await tester.pump();
      await _tap(tester, _button('Rechazar'));

      expect(repo.confirmCalls, hasLength(1));
      final call = repo.confirmCalls.single;
      expect(call.approve, isFalse);
      expect(call.notes, 'Falta evidencia');
      expect(_screenOpen(), isFalse);
      expect(find.text('Sección rechazada'), findsOneWidget);
    });

    testWidgets('cancelling the decision sheet calls nothing', (tester) async {
      final repo = await pumpConfirm(tester);

      await _tap(tester, _button('Rechazar sección'));
      await _tap(tester, _button('Cancelar'));

      expect(repo.confirmCalls, isEmpty);
      expect(_footerButtons(tester),
          unorderedEquals(['Confirmar 70 pts', 'Rechazar sección']));
    });

    testWidgets('the decision sheet names the section', (tester) async {
      await pumpConfirm(tester);

      await _tap(tester, _button('Confirmar 70 pts'));

      // Top bar of the section screen and subtitle of the decision sheet.
      expect(find.text('Sección s1'), findsNWidgets(2));
    });
  });

  group('reopen flow', () {
    testWidgets('confirming the dialog calls reopenSection', (tester) async {
      final repo = await _pumpSection(
        tester,
        section: _section(status: _validated, earnedPoints: 80),
      );

      await _tap(tester, _button('Reabrir sección'));
      expect(find.text('¿Reabrir esta sección?'), findsOneWidget);
      expect(repo.reopenCalls, isEmpty);
      await _tap(tester, _dialogButton('Reabrir sección'));

      expect(repo.reopenCalls, [(folderId: 'f1', sectionId: 's1')]);
      expect(_screenOpen(), isFalse);
      expect(find.text('Sección reabierta'), findsOneWidget);
    });

    testWidgets('cancelling the dialog does not reopen', (tester) async {
      final repo = await _pumpSection(
        tester,
        section: _section(status: _rejected, earnedPoints: 10),
      );

      await _tap(tester, _button('Reabrir sección'));
      await _tap(tester, _dialogButton('Cancelar'));

      expect(repo.reopenCalls, isEmpty);
      expect(_screenOpen(), isTrue);
      expect(find.text('Sección reabierta'), findsNothing);
    });

    testWidgets('a failure shows the error inline and keeps the sheet', (
      tester,
    ) async {
      final repo = _repoWith(
        sections: [_section(status: _validated, earnedPoints: 80)],
      )..onReopen = () async => Left(codedFailure('X', 'No se pudo reabrir'));
      await _pumpSection(tester, repo: repo);

      await _tap(tester, _button('Reabrir sección'));
      await _tap(tester, _dialogButton('Reabrir sección'));

      expect(_sheetText('No se pudo reabrir'), findsOneWidget);
      expect(_footerButtons(tester), ['Reabrir sección']);
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
      await _pumpSection(tester, repo: repoWithNote());

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
      await _pumpSection(tester, repo: repo);

      await _tap(tester, _noteRow('acta.pdf'));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, '');
    });

    testWidgets(
        'saving calls saveReviewerNote and the section sheet stays '
        'open', (tester) async {
      final repo = await _pumpSection(tester, repo: repoWithNote());

      await _tap(tester, _noteRow('acta.pdf'));
      await tester.enterText(find.byType(TextFormField), '  Firma legible  ');
      await tester.pump();
      await _tap(tester, _button('Guardar'));

      expect(repo.noteCalls, [(evidenceId: 'e1', note: 'Firma legible')]);
      expect(find.text('Nota de revisión'), findsNothing);
      expect(_screenOpen(), isTrue);
      expect(_sheetText('Sección s1'), findsOneWidget);
      expect(_footerButtons(tester), ['Evaluar sección']);
    });

    testWidgets('saving a blank note clears it', (tester) async {
      final repo = await _pumpSection(tester, repo: repoWithNote());

      await _tap(tester, _noteRow('acta.pdf'));
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pump();
      await _tap(tester, _button('Guardar'));

      expect(repo.noteCalls, [(evidenceId: 'e1', note: null)]);
    });

    testWidgets('cancelling does not save', (tester) async {
      final repo = await _pumpSection(tester, repo: repoWithNote());

      await _tap(tester, _noteRow('acta.pdf'));
      await _tap(tester, _button('Cancelar'));

      expect(repo.noteCalls, isEmpty);
      expect(_screenOpen(), isTrue);
    });

    testWidgets(
        'a failure shows the error inline and the note can be edited '
        'again', (tester) async {
      final repo = repoWithNote()
        ..onNote = () async => Left(codedFailure('X', 'Nota rechazada'));
      await _pumpSection(tester, repo: repo);

      await _tap(tester, _noteRow('acta.pdf'));
      await _tap(tester, _button('Guardar'));

      expect(repo.noteCalls, hasLength(1));
      expect(_sheetText('Nota rechazada'), findsOneWidget);
      expect(_screenOpen(), isTrue);
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
      await _pumpSection(tester, repo: repo);

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
        await _pumpSection(tester, repo: repo);

        await _evaluateWith(tester, '50');

        expect(repo.evaluateCalls, hasLength(1));
        expect(_sheetText(entry.value), findsOneWidget);
        // The server message is not what the user reads.
        expect(find.text('server says no'), findsNothing);
        expect(_screenOpen(), isTrue);
        expect(_footerButtons(tester), ['Evaluar sección']);
        final action = tester.widget<SacButton>(_button('Evaluar sección'));
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
      await _pumpSection(tester, repo: repo);

      await _evaluateWith(tester, '50');

      expect(_sheetText('Hubo un problema'), findsOneWidget);
      expect(_screenOpen(), isTrue);
    });

    testWidgets('a stale code reloads the folder', (tester) async {
      final repo = _repoWith()
        ..onEvaluate =
            () async => Left(codedFailure('ANNUAL_FOLDER_SECTION_TERMINAL'));
      await _pumpSection(tester, repo: repo);
      expect(repo.folderCalls, ['f1']);

      await _evaluateWith(tester, '50');

      expect(repo.folderCalls, ['f1', 'f1']);
    });

    testWidgets('a non stale code does not reload the folder', (tester) async {
      final repo = _repoWith()
        ..onEvaluate = () async => Left(codedFailure('SOMETHING_NEW'));
      await _pumpSection(tester, repo: repo);

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
      await _pumpSection(tester, repo: repo);

      await _evaluateWith(tester, '50');
      expect(_sheetText('Solo la Unión puede confirmar esta sección.'),
          findsOneWidget);

      await _evaluateWith(tester, '60');

      expect(repo.evaluateCalls.map((c) => c.points), [50, 60]);
      expect(_screenOpen(), isFalse);
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
      await _pumpSection(tester, repo: repo);

      await _evaluateWith(tester, '50');
      expect(_sheetText('Falló'), findsOneWidget);

      await _openEvaluate(tester);
      await _enterPoints(tester, '60');
      await tester.tap(_evaluateConfirm);
      await tester.pump();
      await tester.pump();

      expect(_sheetText('Falló'), findsNothing);
      expect(tester.widget<SacButton>(_button('Evaluar sección')).isLoading,
          isTrue);

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
      await _pumpSection(tester, repo: repo, capabilities: _union);

      await _tap(tester, _button('Confirmar 70 pts'));
      await _tap(tester, _button('Confirmar'));

      expect(_sheetText('Solo la Unión puede confirmar esta sección.'),
          findsOneWidget);
      expect(_footerButtons(tester),
          unorderedEquals(['Confirmar 70 pts', 'Rechazar sección']));
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
      await _pumpSection(tester, repo: repo);

      await _evaluateWith(tester, '50');

      expect(
          _sheetText('Ocurrió un error. Inténtalo de nuevo.'), findsOneWidget);
    });
  });

  group('union confirmation context', () {
    final when = DateTime(2026, 4, 2);

    testWidgets(
        'the Union sees what the local field decided: panel, quote, points', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: _section(
          status: _preapproved,
          earnedPoints: 70,
          evaluationNotes: 'Revisar tesorería',
          lfApproverName: 'Marta Ruiz',
          lfApprovedAt: when,
        ),
        capabilities: _union,
        requiresUnion: true,
      );

      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(_sheetText('Evaluada por el campo local'), findsOneWidget);
      expect(
        _sheetText(
            'Marta Ruiz · ${intl.DateFormat.yMMMd('es').format(when)} · 70 de 100 pts'),
        findsOneWidget,
      );
      expect(find.byType(SupervisionQuote), findsOneWidget);
      expect(_sheetText('Nota del campo local'), findsOneWidget);
      expect(_sheetText('Revisar tesorería'), findsOneWidget);
      // The context replaces the evaluation rows.
      expect(_row('Evaluó'), findsNothing);
    });

    testWidgets('the panel is read-only', (tester) async {
      await _pumpSection(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _union,
        requiresUnion: true,
      );

      expect(tester.widget<SacStatePanel>(find.byType(SacStatePanel)).onTap,
          isNull);
      // No local-field note: no quote.
      expect(find.byType(SupervisionQuote), findsNothing);
    });

    testWidgets('an evaluator without the Union capability gets no panel', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: _section(
          status: _preapproved,
          earnedPoints: 70,
          evaluationNotes: 'Nota',
        ),
        requiresUnion: true,
      );

      expect(find.byType(SacStatePanel), findsNothing);
      expect(find.byType(SupervisionQuote), findsNothing);
    });

    testWidgets('the footer: primary with the points, reject as red text', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: _section(status: _preapproved, earnedPoints: 70),
        capabilities: _union,
        requiresUnion: true,
      );

      expect(find.byType(SacFrostedFooter), findsOneWidget);
      final confirm = _button('Confirmar 70 pts');
      final reject = _button('Rechazar sección');
      expect(tester.widget<SacButton>(reject).variant, SacButtonVariant.ghost);
      expect(tester.getRect(reject).top,
          greaterThan(tester.getRect(confirm).bottom - 1));
    });
  });

  group('success goes back to the folder', () {
    testWidgets('evaluating pops the section screen and reloads the folder', (
      tester,
    ) async {
      final repo = await _pumpSection(tester);

      await _evaluateWith(tester, '85');

      expect(_screenOpen(), isFalse);
      expect(find.text('Sección evaluada'), findsOneWidget);
      expect(repo.folderCalls, ['f1', 'f1']);
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

    testWidgets('screen at 320 wide and text scale 2.0 does not overflow', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: heavySectionOf(),
        size: narrow,
        textScale: 2.0,
      );

      expectNoLayoutException(tester);
      expect(_footerButtons(tester), ['Evaluar sección']);
    });

    testWidgets(
        'evaluation facts at 320 wide and text scale 2.0 do not overflow', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: heavySectionOf(withFacts: true),
        size: narrow,
        textScale: 2.0,
      );

      expectNoLayoutException(tester);
      expect(_row('Evaluó'), findsOneWidget);
    });

    // EvidenceFileGallery._FileTile lays a 28 px icon plus a two-line label
    // inside a fixed 1:1 grid cell; at scale 2.0 the label alone is taller
    // than the cell (a known limit of the shared gallery).
    testWidgets('file evidences at 320 wide do not overflow', (tester) async {
      await _pumpSection(
        tester,
        section: heavySectionOf(withFiles: true),
        size: narrow,
      );

      expectNoLayoutException(tester);
      expect(_sheetText('NOTAS DE REVISIÓN'), findsOneWidget);
    });

    testWidgets('Union panel and footer at 320 wide and scale 2.0 fit', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: _section(
          status: _preapproved,
          earnedPoints: 70,
          evaluationNotes: 'Revisar tesorería con el tesorero del club',
          lfApproverName: 'Marta Gutiérrez de la Cruz',
          lfApprovedAt: DateTime(2026, 4, 2),
        ),
        capabilities: _union,
        requiresUnion: true,
        size: narrow,
        textScale: 2.0,
      );

      expectNoLayoutException(tester);
      expect(_footerButtons(tester),
          unorderedEquals(['Confirmar 70 pts', 'Rechazar sección']));
    });

    testWidgets('evaluate sheet at 320 wide and scale 2.0 does not overflow', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        section: heavySectionOf(),
        size: narrow,
        textScale: 2.0,
      );
      await tester.tap(_button('Evaluar sección'));
      await tester.pumpAndSettle();
      await _enterPoints(tester, '101');
      await tester.tap(_evaluateConfirm);
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
      expect(find.text('Escribe un número entre 0 y 100.'), findsOneWidget);
    });
  });
}
