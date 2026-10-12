import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/widgets/instructor_picker.dart';
import 'package:sacdia_app/core/widgets/instructor_selection.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/instructor_proposal.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/repositories/honors_repository.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_evidence_view.dart';

import '../../../certificate_import/support/test_app.dart';
import '../../../../support/instructor_fakes.dart';

const _juan = InstructorSelection.external('Juan López');

/// Plays the API for the proposal endpoints: POST replaces the pending one,
/// DELETE withdraws it, and the list shows what is left.
class _FakeHonorsRepository extends Fake implements HonorsRepository {
  _FakeHonorsRepository({
    this.status = 'APPROVED',
    this.supports = true,
    this.instructor,
    this.proposal,
  });

  String status;
  bool supports;
  InstructorSelection? instructor;
  InstructorProposal? proposal;
  Failure? failWith;
  final proposed = <InstructorSelection>[];
  var cancelCalls = 0;
  final patches = <Map<String, dynamic>>[];

  UserHonor get row => UserHonor(
        id: 77,
        honorId: 7,
        userId: 'user-1',
        completionMode: HonorCompletionMode.external,
        validationStatus: status,
        document: 'https://example.com/completed.pdf',
        images: const ['https://example.com/photo.jpg'],
        date: DateTime(2026, 6, 11),
        completedAt: DateTime(2026, 9, 30),
        instructor: instructor,
        instructorProposal: proposal,
        supportsInstructorProposal: supports,
      );

  @override
  Future<Either<Failure, InstructorProposal>> proposeHonorInstructor(
    String userId,
    int honorId,
    InstructorSelection next,
  ) async {
    proposed.add(next);
    final failure = failWith;
    if (failure != null) return Left(failure);
    proposal = InstructorProposal(
      proposalId: 'p-${proposed.length}',
      status: InstructorProposalStatus.pending,
      instructor: next,
    );
    return Right(proposal!);
  }

  @override
  Future<Either<Failure, void>> cancelHonorInstructorProposal(
    String userId,
    int honorId,
  ) async {
    cancelCalls++;
    final failure = failWith;
    if (failure != null) return Left(failure);
    proposal = null;
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserHonor>> updateUserHonor(
    String userId,
    int honorId,
    Map<String, dynamic> data,
  ) async {
    patches.add(data);
    return Right(row);
  }
}

/// The screen keeps a looping animation alive, so `pumpAndSettle` never ends.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(WidgetTester tester, _FakeHonorsRepository repo) async {
  phoneSurface(tester, height: 3200);
  const honor = Honor(
    id: 7,
    name: 'Arte de acampar',
    categoryId: 1,
    approval: 1,
    clubTypeId: 1,
  );
  await tester.pumpWidget(wrapTestApp(
    const HonorEvidenceView(honorId: 7, userHonorId: 77),
    overrides: [
      allHonorsProvider.overrideWith((ref) async => [honor]),
      activeHonorCatalogClubTypeIdProvider
          .overrideWith((ref) => const AsyncValue.data(null)),
      userHonorsProvider.overrideWith((ref) async => [repo.row]),
      honorsRepositoryProvider.overrideWithValue(repo),
      FakeInstructorSearch().override,
    ],
  ));
  await _settle(tester);
}

/// Opens the picker from [action] and chooses Ana Gómez.
Future<void> _pickAna(WidgetTester tester, Finder opener) async {
  await tester.tap(opener);
  await _settle(tester);
  await tester.enterText(
    find.descendant(
      of: find.byType(InstructorPicker),
      matching: find.byType(TextField),
    ),
    'Ana',
  );
  await tester.pump(const Duration(milliseconds: 300));
  await _settle(tester);
  await tester.tap(find.descendant(
    of: find.byType(InstructorPicker),
    matching: find.text('Ana Gómez'),
  ));
  await _settle(tester);
}

Future<void> _tapInDialog(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(SacDialog),
    matching: find.text(label),
  ));
  await _settle(tester);
}

Future<void> _propose(WidgetTester tester, String action) async {
  await _pickAna(tester, find.widgetWithText(SacButton, action));
  await _tapInDialog(tester, 'Proponer');
}

const _pendingJuan = InstructorProposal(
  proposalId: 'p-0',
  status: InstructorProposalStatus.pending,
  instructor: _juan,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initTestLocalization);

  group('the five states of an approved honor', () {
    testWidgets('1. no instructor: says so and offers to propose',
        (tester) async {
      await _pump(tester, _FakeHonorsRepository());

      expect(find.text('Sin instructor registrado'), findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Proponer instructor'),
          findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Quitar'), findsNothing);
      expect(find.text('Instructor en revisión'), findsNothing);
    });

    testWidgets('2. with instructor: shown, no Quitar, can propose another',
        (tester) async {
      await _pump(tester, _FakeHonorsRepository(instructor: _juan));

      expect(find.text('Juan López'), findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Quitar'), findsNothing);
      expect(find.widgetWithText(SacButton, 'Proponer otro instructor'),
          findsOneWidget);
      expect(
          find.widgetWithText(SacButton, 'Proponer instructor'), findsNothing);
    });

    testWidgets('3. pending: badge, proposed person, what stays, two actions',
        (tester) async {
      await _pump(
        tester,
        _FakeHonorsRepository(
          instructor: _juan,
          proposal: const InstructorProposal(
            status: InstructorProposalStatus.pending,
            instructor: anaGomez,
          ),
        ),
      );

      expect(find.text('Instructor en revisión'), findsOneWidget);
      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(
        find.text('Tu Campo Local revisará esta propuesta. '
            'Mientras tanto se mantiene Juan López.'),
        findsOneWidget,
      );
      expect(
          find.widgetWithText(SacButton, 'Cambiar propuesta'), findsOneWidget);
      expect(
          find.widgetWithText(SacButton, 'Cancelar propuesta'), findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Proponer otro instructor'),
          findsNothing);
    });

    testWidgets('3b. pending without a current instructor', (tester) async {
      await _pump(tester, _FakeHonorsRepository(proposal: _pendingJuan));

      expect(
        find.text('Tu Campo Local revisará esta propuesta. '
            'Mientras tanto se mantiene sin instructor.'),
        findsOneWidget,
      );
    });

    testWidgets('4. rejected: reason, the current instructor, propose again',
        (tester) async {
      await _pump(
        tester,
        _FakeHonorsRepository(
          instructor: _juan,
          proposal: const InstructorProposal(
            status: InstructorProposalStatus.rejected,
            instructor: anaGomez,
            rejectionReason: 'No es de tu Campo Local',
          ),
        ),
      );

      expect(find.text('Tu Campo Local rechazó la propuesta'), findsOneWidget);
      expect(find.text('Motivo: No es de tu Campo Local'), findsOneWidget);
      expect(find.text('Juan López'), findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Proponer otro instructor'),
          findsOneWidget);
    });

    testWidgets('5. approved: the person is now the instructor',
        (tester) async {
      await _pump(
        tester,
        _FakeHonorsRepository(
          instructor: anaGomez,
          proposal: const InstructorProposal(
            status: InstructorProposalStatus.approved,
            instructor: anaGomez,
          ),
        ),
      );

      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(find.text('Instructor en revisión'), findsNothing);
      expect(find.text('Tu Campo Local rechazó la propuesta'), findsNothing);
      expect(find.widgetWithText(SacButton, 'Proponer otro instructor'),
          findsOneWidget);
    });
  });

  group('proposing', () {
    testWidgets('asks first, then POSTs and swaps to "en revisión"',
        (tester) async {
      final repo = _FakeHonorsRepository();
      await _pump(tester, repo);

      await _pickAna(
          tester, find.widgetWithText(SacButton, 'Proponer instructor'));

      // Nothing is sent before the member confirms.
      expect(repo.proposed, isEmpty);
      expect(find.text('¿Proponer a Ana Gómez?'), findsOneWidget);
      expect(find.textContaining('Tu Campo Local revisará la propuesta.'),
          findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SacDialog),
          matching: find.textContaining('No avisamos a la persona.'),
        ),
        findsOneWidget,
      );

      await _tapInDialog(tester, 'Proponer');

      expect(repo.proposed, [anaGomez]);
      expect(repo.patches, isEmpty);
      expect(find.text('Instructor en revisión'), findsOneWidget);
      expect(
          find.widgetWithText(SacButton, 'Cancelar propuesta'), findsOneWidget);
    });

    testWidgets('a typed name is proposed as such', (tester) async {
      final repo = _FakeHonorsRepository(instructor: anaGomez);
      await _pump(tester, repo);

      await tester
          .tap(find.widgetWithText(SacButton, 'Proponer otro instructor'));
      await _settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(InstructorPicker),
          matching: find.byType(TextField),
        ),
        'Juan López',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _settle(tester);
      await tester.tap(find.text('Usar «Juan López» como nombre'));
      await _settle(tester);
      await _tapInDialog(tester, 'Proponer');

      expect(repo.proposed, [_juan]);
      expect(find.text('Nombre escrito · no verificado'), findsOneWidget);
    });

    testWidgets('declining the dialog sends nothing', (tester) async {
      final repo = _FakeHonorsRepository();
      await _pump(tester, repo);

      await _pickAna(
          tester, find.widgetWithText(SacButton, 'Proponer instructor'));
      await _tapInDialog(tester, 'Cancelar');

      expect(repo.proposed, isEmpty);
      expect(find.text('Sin instructor registrado'), findsOneWidget);
    });

    testWidgets('proposing the current instructor is refused locally',
        (tester) async {
      final repo = _FakeHonorsRepository(instructor: anaGomez);
      await _pump(tester, repo);

      await _pickAna(
          tester, find.widgetWithText(SacButton, 'Proponer otro instructor'));

      expect(find.text('Esa persona ya es tu instructor'), findsOneWidget);
      expect(find.byType(SacDialog), findsNothing);
      expect(repo.proposed, isEmpty);
    });

    testWidgets('changing a pending proposal POSTs again and replaces it',
        (tester) async {
      final repo = _FakeHonorsRepository(proposal: _pendingJuan);
      await _pump(tester, repo);

      await _propose(tester, 'Cambiar propuesta');

      expect(repo.proposed, [anaGomez]);
      expect(repo.cancelCalls, 0);
      expect(find.text('Instructor en revisión'), findsOneWidget);
      expect(find.text('Ana Gómez'), findsOneWidget);
      expect(find.text('Juan López'), findsNothing);
    });

    testWidgets('the swap also runs with Reduced Motion', (tester) async {
      reduceMotion(tester);
      final repo = _FakeHonorsRepository();
      await _pump(tester, repo);

      await _propose(tester, 'Proponer instructor');

      expect(find.text('Instructor en revisión'), findsOneWidget);
    });
  });

  group('withdrawing', () {
    testWidgets('confirms, DELETEs, and goes back to proposing',
        (tester) async {
      final repo = _FakeHonorsRepository(
        instructor: _juan,
        proposal: const InstructorProposal(
          status: InstructorProposalStatus.pending,
          instructor: anaGomez,
        ),
      );
      await _pump(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Cancelar propuesta'));
      await _settle(tester);

      expect(find.text('¿Cancelar la propuesta?'), findsOneWidget);
      expect(find.text('Se mantiene Juan López.'), findsOneWidget);
      expect(repo.cancelCalls, 0);

      await _tapInDialog(tester, 'Cancelar propuesta');

      expect(repo.cancelCalls, 1);
      expect(find.text('Instructor en revisión'), findsNothing);
      expect(find.text('Juan López'), findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Proponer otro instructor'),
          findsOneWidget);
    });

    testWidgets('"Volver" keeps the proposal', (tester) async {
      final repo = _FakeHonorsRepository(proposal: _pendingJuan);
      await _pump(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Cancelar propuesta'));
      await _settle(tester);
      expect(find.text('Se mantiene sin instructor.'), findsOneWidget);
      await _tapInDialog(tester, 'Volver');

      expect(repo.cancelCalls, 0);
      expect(find.text('Instructor en revisión'), findsOneWidget);
    });

    testWidgets('a failure explains itself and keeps the proposal',
        (tester) async {
      final repo = _FakeHonorsRepository(proposal: _pendingJuan)
        ..failWith = const ServerFailure(message: 'x');
      await _pump(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Cancelar propuesta'));
      await _settle(tester);
      await _tapInDialog(tester, 'Cancelar propuesta');

      expect(find.text('No pudimos cancelar la propuesta. Inténtalo de nuevo'),
          findsOneWidget);
      expect(find.text('Instructor en revisión'), findsOneWidget);
    });
  });

  group('the decision shows up without a notification (D8)', () {
    testWidgets('returning to the app re-reads a pending proposal',
        (tester) async {
      final repo = _FakeHonorsRepository(proposal: _pendingJuan);
      await _pump(tester, repo);
      expect(find.text('Instructor en revisión'), findsOneWidget);

      // The Local Field approved it meanwhile.
      repo
        ..proposal = null
        ..instructor = anaGomez;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(find.text('Instructor en revisión'), findsNothing);
      expect(find.text('Ana Gómez'), findsOneWidget);
    });
  });

  group('errors', () {
    for (final (failure, message) in [
      (
        const ServerFailure(
            message: 'x', code: 400, errorCode: 'HONOR_INSTRUCTOR_INVALID'),
        'Esta persona no está disponible. Elige a otra o escribe su nombre',
      ),
      (
        const ServerFailure(
            message: 'x', code: 400, errorCode: 'HONOR_INSTRUCTOR_SELF'),
        'No puedes ser tu propio instructor',
      ),
      (
        const ServerFailure(
            message: 'x', code: 400, errorCode: 'HONOR_INSTRUCTOR_UNCHANGED'),
        'Esa persona ya es tu instructor',
      ),
      (
        const ServerFailure(message: 'x', code: 429),
        'Estás enviando propuestas muy rápido. '
            'Espera unos segundos e inténtalo de nuevo.',
      ),
      (
        const ServerFailure(
            message: 'x',
            code: 400,
            errorCode: 'HONOR_INSTRUCTOR_PROPOSAL_NOT_APPROVED'),
        'Esta especialidad cambió de estado. Actualizamos la pantalla.',
      ),
      (
        const ServerFailure(message: 'x', code: 409),
        'Esta especialidad cambió de estado. Actualizamos la pantalla.',
      ),
    ]) {
      testWidgets('${failure.errorCode ?? failure.code} lands on the card',
          (tester) async {
        final repo = _FakeHonorsRepository()..failWith = failure;
        await _pump(tester, repo);

        await _propose(tester, 'Proponer instructor');

        expect(find.text(message), findsOneWidget);
        expect(find.textContaining('HONOR_'), findsNothing);
        expect(find.text('Instructor en revisión'), findsNothing);
        expect(find.widgetWithText(SacButton, 'Proponer instructor'),
            findsOneWidget);
      });
    }

    testWidgets('anything else is a banner and the card stays as it was',
        (tester) async {
      final repo = _FakeHonorsRepository()
        ..failWith = const ServerFailure(message: 'x');
      await _pump(tester, repo);

      await _propose(tester, 'Proponer instructor');

      expect(find.text('No pudimos enviar la propuesta. Inténtalo de nuevo'),
          findsOneWidget);
      expect(find.text('Sin instructor registrado'), findsOneWidget);
    });
  });

  group('no proposal UI outside APPROVED', () {
    for (final status in ['IN_PROGRESS', 'REJECTED']) {
      testWidgets('$status keeps the S7 flow with PATCH', (tester) async {
        final repo = _FakeHonorsRepository(status: status);
        await _pump(tester, repo);

        expect(find.text('Agregar instructor (opcional)'), findsOneWidget);
        expect(find.widgetWithText(SacButton, 'Proponer instructor'),
            findsNothing);
        expect(find.text('Instructor en revisión'), findsNothing);

        await _pickAna(tester, find.text('Agregar instructor (opcional)'));
        expect(repo.proposed, isEmpty);
      });
    }

    testWidgets('PENDING_REVIEW is read-only', (tester) async {
      await _pump(
        tester,
        _FakeHonorsRepository(status: 'PENDING_REVIEW', instructor: _juan),
      );

      expect(find.text('Juan López'), findsOneWidget);
      expect(find.widgetWithText(SacButton, 'Proponer otro instructor'),
          findsNothing);
    });

    testWidgets('APPROVED on a backend without the key stays read-only',
        (tester) async {
      await _pump(tester, _FakeHonorsRepository(supports: false));

      expect(find.text('Sin instructor registrado'), findsOneWidget);
      expect(
          find.widgetWithText(SacButton, 'Proponer instructor'), findsNothing);
    });
  });
}
