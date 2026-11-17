import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/utils/counselor_rows.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_counselor_assignments_view.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

import '../grouped_class_test_support.dart';

const _query = ClassCounselorAssignmentsQuery(
  clubId: 7,
  sectionId: 3,
  yearId: 12,
  active: true,
);

const _classes = [
  ProgressiveClass(id: 3, name: 'Explorador', clubTypeId: 2),
  ProgressiveClass(id: 1, name: 'Amigo', clubTypeId: 2),
  ProgressiveClass(id: 2, name: 'Compañero', clubTypeId: 2),
];

ClubMember _member(String id, String name, {String role = 'counselor'}) =>
    ClubMember(
      userId: id,
      name: name,
      paternalSurname: 'Pérez',
      clubRole: role,
      classCounselorEligible: true,
    );

final _candidates = [
  _member('ana', 'Ana'),
  _member('beto', 'Beto'),
  _member('carla', 'Carla', role: 'secretary'),
  // Not assignable: a plain member.
  _member('dani', 'Dani', role: 'member'),
];

final _assignments = [
  assignment(
    id: 'a1',
    userId: 'laura',
    name: 'Laura Méndez',
    classId: 1,
    className: 'Amigo',
  ),
  assignment(
    id: 'a1b',
    userId: 'diego',
    name: 'Diego Paredes',
    classId: 1,
    className: 'Amigo',
    responsibility: 'assistant',
  ),
  assignment(
    id: 'a2',
    userId: 'ruben',
    name: 'Rubén Salas',
    classId: 2,
    className: 'Compañero',
  ),
];

class _FakeMembers extends MembersNotifier {
  _FakeMembers(this.members);

  final List<ClubMember> members;

  @override
  Future<MembersData> build() async => MembersData(members: members);
}

void main() {
  setUpAll(initGroupedClassL10n);

  Future<FakeAssignmentsRepository> pump(
    WidgetTester tester, {
    FakeAssignmentsRepository? repository,
    List<ClubMember>? members,
  }) async {
    final repo = repository ?? FakeAssignmentsRepository();
    await pumpGroupedApp(
      tester,
      user: directorUser,
      size: const Size(420, 2400),
      home: const ClassCounselorAssignmentsView(
        clubId: 7,
        sectionId: 3,
        clubTypeId: 2,
        yearId: 12,
      ),
      overrides: [
        classesRepositoryProvider.overrideWithValue(repo),
        classCounselorAssignmentsProvider(_query)
            .overrideWith((ref) async => _assignments),
        classesByClubTypeProvider(2).overrideWith((ref) async => _classes),
        membersNotifierProvider
            .overrideWith(() => _FakeMembers(members ?? _candidates)),
      ],
    );
    return repo;
  }

  Finder detailOf(int classId, String text) => find.descendant(
        of: find.byKey(ValueKey('counselor-row-$classId')),
        matching: find.text(text),
      );

  testWidgets('one row per class, youngest first, with its people',
      (tester) async {
    await pump(tester);

    final amigo =
        tester.getTopLeft(find.byKey(const ValueKey('counselor-row-1')));
    final companero =
        tester.getTopLeft(find.byKey(const ValueKey('counselor-row-2')));
    final explorador =
        tester.getTopLeft(find.byKey(const ValueKey('counselor-row-3')));
    expect(amigo.dy, lessThan(companero.dy));
    expect(companero.dy, lessThan(explorador.dy));

    expect(detailOf(1, 'Laura Méndez · Diego Paredes'), findsOneWidget);
    expect(detailOf(2, 'Rubén Salas · sin subconsejero'), findsOneWidget);
    expect(detailOf(3, 'Sin consejero asignado'), findsOneWidget);
  });

  testWidgets('the intro says who can be counselor', (tester) async {
    await pump(tester);
    expect(find.textContaining('Guía Mayor'), findsOneWidget);
  });

  testWidgets('class without counselor: pick one and save creates it',
      (tester) async {
    final repo = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('counselor-row-3')));
    await tester.pumpAndSettle();

    // No responsibility dropdown and no "substitute" in the sheet.
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.textContaining('Suplente'), findsNothing);
    expect(find.text('Elegir'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('assign-field-counselor')));
    await tester.pumpAndSettle();
    // Only people who can be responsible, not the plain member.
    expect(find.byKey(const ValueKey('assign-pick-ana')), findsOneWidget);
    expect(find.byKey(const ValueKey('assign-pick-carla')), findsOneWidget);
    expect(find.byKey(const ValueKey('assign-pick-dani')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('assign-pick-ana')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('assign-save')));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c != 'list'), ['create:ana:3:primary']);
    expect(find.text('Asignación guardada.'), findsOneWidget);
    expect(find.byKey(const ValueKey('assign-save')), findsNothing);
  });

  testWidgets('adding only a sub-counselor creates one assistant',
      (tester) async {
    final repo = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('counselor-row-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-field-assistant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-pick-beto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-save')));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c != 'list'), ['create:beto:2:assistant']);
  });

  testWidgets('replacing the counselor revokes first, then creates',
      (tester) async {
    final repo = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('counselor-row-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-field-counselor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-pick-ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-save')));
    await tester.pumpAndSettle();

    // A person cannot be changed in place: delete + create.
    expect(
      repo.calls.where((c) => c != 'list'),
      ['revoke:a2', 'create:ana:2:primary'],
    );
  });

  testWidgets('the sub-counselor can be cleared', (tester) async {
    final repo = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('counselor-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-field-assistant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-pick-none')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-save')));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c != 'list'), ['revoke:a1b']);
  });

  testWidgets('Quitar asks first and revokes counselor and sub-counselor',
      (tester) async {
    final repo = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('counselor-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-remove')));
    await tester.pumpAndSettle();

    expect(find.text('Quitar consejeros'), findsOneWidget);
    expect(repo.calls.where((c) => c != 'list'), isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Quitar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c != 'list'), ['revoke:a1', 'revoke:a1b']);
    expect(find.text('Asignación quitada.'), findsOneWidget);
  });

  testWidgets('a class with nobody has no Quitar', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('counselor-row-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assign-remove')), findsNothing);
  });

  testWidgets('CLASS_COUNSELOR_ASSISTANT_EXISTS shows its own message',
      (tester) async {
    final repo = await pump(
      tester,
      repository: FakeAssignmentsRepository(
        createFailure: const ServerFailure(
          message: 'raw server text',
          code: 409,
          errorCode: 'CLASS_COUNSELOR_ASSISTANT_EXISTS',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('counselor-row-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-field-assistant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-pick-beto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-save')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ya tiene un subconsejero'),
      findsOneWidget,
    );
    expect(find.textContaining('raw server text'), findsNothing);
    // Nothing was revoked, so there is nothing to restore.
    expect(repo.calls.where((c) => c != 'list'), ['create:beto:2:assistant']);
    // The sheet stays open to try again.
    expect(find.byKey(const ValueKey('assign-save')), findsOneWidget);
  });

  testWidgets('CLASS_COUNSELOR_PRIMARY_EXISTS and GUIDE_MAJOR_REQUIRED too',
      (tester) async {
    for (final (code, text) in [
      ('CLASS_COUNSELOR_PRIMARY_EXISTS', 'ya tiene un consejero'),
      ('CLASS_COUNSELOR_GUIDE_MAJOR_REQUIRED', 'Guía Mayor'),
    ]) {
      final repo = FakeAssignmentsRepository(
        createFailure: ServerFailure(
          message: 'raw',
          code: 409,
          errorCode: code,
        ),
      );
      await pump(tester, repository: repo);
      await tester.tap(find.byKey(const ValueKey('counselor-row-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-field-counselor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-pick-ana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-save')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('assign-error'))).data,
        contains(text),
        reason: code,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a failed replacement restores the previous counselor',
      (tester) async {
    final repo = await pump(
      tester,
      repository: FakeAssignmentsRepository(
        createFailure: const ServerFailure(
          message: 'raw',
          code: 400,
          errorCode: 'CLASS_COUNSELOR_GUIDE_MAJOR_REQUIRED',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('counselor-row-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-field-counselor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-pick-ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assign-save')));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c != 'list'), [
      'revoke:a2',
      'create:ana:2:primary',
      // Rollback: the class does not lose the counselor it had.
      'create:ruben:2:primary',
    ]);
  });

  testWidgets('without candidates there is nothing to pick', (tester) async {
    await pump(tester, members: [_member('dani', 'Dani', role: 'member')]);

    await tester.tap(find.byKey(const ValueKey('counselor-row-3')));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('No hay consejeros o secretaría'), findsOneWidget);
    expect(find.byKey(const ValueKey('assign-save')), findsNothing);
  });

  group('counselor rows', () {
    final byClass = buildCounselorRows(_classes, _assignments);
    ClassCounselorRow row(int id) => byClass.firstWhere((r) => r.classId == id);

    test('one row per class, ordered youngest first', () {
      expect(byClass.map((r) => r.name), ['Amigo', 'Compañero', 'Explorador']);
    });

    test('splits counselor and sub-counselor and ignores substitutes', () {
      expect(row(1).primary?.userId, 'laura');
      expect(row(1).assistant?.userId, 'diego');
      expect(row(2).assistant, isNull);
      expect(row(3).hasCounselor, isFalse);

      final withSubstitute = buildCounselorRows(_classes, [
        assignment(
          id: 's',
          userId: 'sub',
          name: 'Sub',
          classId: 3,
          className: 'Explorador',
          responsibility: 'substitute',
        ),
      ]);
      expect(
        withSubstitute.firstWhere((r) => r.classId == 3).hasAnyAssignment,
        isFalse,
      );
    });

    test('a class only present in an assignment still gets a row', () {
      final rows = buildCounselorRows(const [], [_assignments.first]);
      expect(rows.single.name, 'Amigo');
    });

    test('plan: same people means no changes', () {
      final plan = planAssignmentChange(
        row(1),
        counselorId: 'laura',
        assistantId: 'diego',
      );
      expect(plan.isEmpty, isTrue);
    });

    test('plan: swap revokes both before creating both', () {
      final plan = planAssignmentChange(
        row(1),
        counselorId: 'diego',
        assistantId: 'laura',
      );
      expect(plan.revokes.map((a) => a.assignmentId), ['a1', 'a1b']);
      expect(plan.creates, [
        ('diego', 'primary'),
        ('laura', 'assistant'),
      ]);
    });

    test('plan: clearing the assistant only revokes', () {
      final plan = planAssignmentChange(
        row(1),
        counselorId: 'laura',
        assistantId: null,
      );
      expect(plan.revokes.map((a) => a.assignmentId), ['a1b']);
      expect(plan.creates, isEmpty);
    });
  });
}
