import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_members_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_progress_summary.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/utils/member_requirement_groups.dart';
import 'package:sacdia_app/features/classes/presentation/views/member_progress_view.dart';

import '../grouped_class_test_support.dart';

const _progressQuery = ClassProgressQuery(
  classId: 3,
  enrollmentId: 55,
  targetUserId: 'x',
);
const _membersQuery = ClassMembersProgressQuery(
  clubId: 7,
  sectionId: 3,
  classId: 3,
  yearId: 12,
);

final _requirements = [
  requirement(1, 'Memorizar el voto y la ley', RequirementStatus.validado,
      validatedAt: DateTime(2026, 10, 28)),
  requirement(2, 'Leer el libro del año', RequirementStatus.validado,
      validatedAt: DateTime(2026, 10, 28)),
  requirement(3, 'Participar en 3 cultos', RequirementStatus.enviado,
      submittedAt: DateTime(2026, 11, 5)),
  requirement(4, 'Memorizar 5 versículos', RequirementStatus.rechazado,
      rejectionReason: 'La grabación no se escucha; vuelve a subirla.'),
  requirement(5, 'Historia de la creación', RequirementStatus.enviado,
      submittedAt: DateTime(2026, 11, 5)),
  requirement(6, 'Estudio de un personaje', RequirementStatus.pendiente,
      files: 1),
  requirement(7, 'Proyecto comunitario', RequirementStatus.pendiente),
  requirement(8, 'Visitar a un enfermo', RequirementStatus.validado,
      validatedAt: DateTime(2026, 10, 28)),
];

void main() {
  setUpAll(initGroupedClassL10n);

  Future<Navigated> pump(
    WidgetTester tester, {
    List<ClassRequirement>? requirements,
    bool withMembers = true,
  }) {
    return pumpGroupedApp(
      tester,
      user: counselorUser,
      home: const MemberProgressView(
        classId: 3,
        userId: 'x',
        enrollmentId: 55,
        clubId: 7,
        sectionId: 3,
        yearId: 12,
        className: 'Explorador',
        memberName: 'Ximena Delgado',
      ),
      overrides: [
        classWithProgressProvider(_progressQuery).overrideWith(
          (ref) async => classWithRequirements(
            requirements ?? _requirements,
            overallProgress: 38,
          ),
        ),
        if (withMembers)
          classMembersProgressProvider(_membersQuery).overrideWith(
            (ref) async => const ClassMembersProgressResult(
              clubSectionId: 3,
              clubTypeId: 2,
              classId: 3,
              ecclesiasticalYearId: 12,
              accessLevel: 'section',
              members: [],
              counselor: ClassResponsible(userId: 'c', name: 'Mateo Herrera'),
            ),
          ),
      ],
    );
  }

  testWidgets('summary: ready of total, what is missing and investiture',
      (tester) async {
    await pump(tester);

    final summary = find.byKey(const ValueKey('grouped-member-summary'));
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('3 de 8', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('faltan 5', findRichText: true),
      ),
      findsOneWidget,
    );
    for (final label in [
      '3 validados',
      '2 en revisión',
      '1 por corregir',
      '2 sin enviar',
    ]) {
      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining(label, findRichText: true),
        ),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.descendant(of: summary, matching: find.text('38%')),
        findsOneWidget);
  });

  testWidgets('title and subtitle name the member, class and counselor',
      (tester) async {
    await pump(tester);
    expect(find.text('Ximena Delgado'), findsOneWidget);
    expect(find.text('Explorador · Consejero: Mateo Herrera'), findsOneWidget);
  });

  testWidgets('groups: attention first, then review, then validated',
      (tester) async {
    await pump(tester);

    double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;

    final attention = top('grouped-member-group-attention');
    final review = top('grouped-member-group-review');
    final validated = top('grouped-member-group-validated');
    expect(attention, lessThan(review));
    expect(review, lessThan(validated));

    // Sent back before not sent, inside the first group.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('grouped-requirement-4'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('grouped-requirement-6')))
            .dy,
      ),
    );
    expect(find.text('Por atender'.toUpperCase()), findsOneWidget);
    expect(find.text('En revisión'.toUpperCase()), findsOneWidget);
    expect(find.text('Validados'.toUpperCase()), findsOneWidget);
  });

  testWidgets('each state has its own detail line', (tester) async {
    await pump(tester);

    Finder detailOf(int id, String text) => find.descendant(
          of: find.byKey(ValueKey('grouped-requirement-$id')),
          matching: find.text(text),
        );

    expect(detailOf(4, '«La grabación no se escucha; vuelve a subirla.»'),
        findsOneWidget);
    expect(detailOf(6, '1 de 10 archivos'), findsOneWidget);
    expect(detailOf(7, 'Sin archivos'), findsOneWidget);
    expect(detailOf(3, 'Enviado el 5 nov'), findsOneWidget);
    expect(detailOf(1, 'Validado el 28 oct'), findsOneWidget);
  });

  testWidgets('tapping a requirement opens it for this member', (tester) async {
    final navigated = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('grouped-requirement-4')));
    await tester.pumpAndSettle();

    expect(
      navigated.last.path,
      '/home/grouped-class/class/3/member/x/requirement/4',
    );
    expect(navigated.last.queryParameters['enrollmentId'], '55');
    expect(navigated.last.queryParameters['memberName'], 'Ximena Delgado');
  });

  testWidgets('a group with no requirements is left out', (tester) async {
    await pump(tester, requirements: [_requirements.first]);

    expect(find.byKey(const ValueKey('grouped-member-group-validated')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('grouped-member-group-attention')),
        findsNothing);
    expect(find.byKey(const ValueKey('grouped-member-group-review')),
        findsNothing);
  });

  testWidgets('a class without requirements shows an empty state',
      (tester) async {
    await pump(tester, requirements: const []);
    expect(find.text('Sin requisitos'), findsOneWidget);
  });

  group('requirement grouping', () {
    test('sent back and observed count as to fix', () {
      final counts = countRequirements([
        requirement(1, 'a', RequirementStatus.rechazado),
        requirement(2, 'b', RequirementStatus.observado),
        requirement(3, 'c', RequirementStatus.enviado),
        requirement(4, 'd', RequirementStatus.pendiente),
        requirement(5, 'e', RequirementStatus.validado),
      ]);
      expect(counts.rejected, 2);
      expect(counts.submitted, 1);
      expect(counts.pending, 1);
      expect(counts.validated, 1);
      expect(counts.total, 5);
    });

    test('groupRequirements orders attention with sent back first', () {
      final groups = groupRequirements([
        requirement(1, 'pending', RequirementStatus.pendiente),
        requirement(2, 'observed', RequirementStatus.observado),
        requirement(3, 'rejected', RequirementStatus.rechazado),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.$1, MemberRequirementGroup.attention);
      expect(groups.single.$2.map((r) => r.id), [2, 3, 1]);
    });
  });
}
