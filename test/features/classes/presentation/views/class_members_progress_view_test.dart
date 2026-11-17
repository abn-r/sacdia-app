import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_members_progress.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_progress_summary.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/class_members_progress_view.dart';
import 'package:sacdia_app/features/classes/presentation/widgets/grouped_members_body.dart';

import '../grouped_class_test_support.dart';

const _query = ClassMembersProgressQuery(
  clubId: 7,
  sectionId: 3,
  classId: 3,
  yearId: 12,
);

ClassMemberProgress _member(
  String id,
  String name,
  int progress, {
  int validated = 0,
  int rejected = 0,
  int total = 12,
  bool crossType = false,
}) =>
    ClassMemberProgress(
      userId: id,
      name: name,
      enrollmentId: 100 + id.length,
      classId: 3,
      ecclesiasticalYearId: 12,
      investitureStatus: 'IN_PROGRESS',
      completedSections: validated,
      totalSections: total,
      overallProgress: progress,
      crossTypeEnrollment: crossType,
      statusCounts: RequirementStatusCounts(
        validated: validated,
        rejected: rejected,
        pending: total - validated - rejected,
      ),
    );

// Unsorted on purpose: the screen sorts lowest progress first.
final _members = [
  _member('a', 'Valeria Torres', 92, validated: 11),
  _member('e', 'Regina Flores', 58, validated: 7),
  _member('i', 'Iker Navarro', 12, validated: 1, rejected: 2),
  _member('l', 'Lucía Romero', 0),
  _member('t', 'Tomás Aguilar', 45, validated: 5, rejected: 1),
  _member('x', 'Ximena Delgado', 30, validated: 4),
];

ClassMembersProgressResult _result({
  List<ClassMemberProgress>? members,
  ClassResponsible? counselor = const ClassResponsible(
    userId: 'c1',
    name: 'Mateo Herrera',
  ),
  ClassResponsible? assistant,
}) =>
    ClassMembersProgressResult(
      clubSectionId: 3,
      clubTypeId: 2,
      classId: 3,
      ecclesiasticalYearId: 12,
      accessLevel: 'section',
      members: members ?? _members,
      summary: const ClassProgressSummary(
        avgProgress: 35,
        statusCounts: RequirementStatusCounts(
          validated: 28,
          submitted: 12,
          rejected: 3,
          pending: 29,
        ),
      ),
      counselor: counselor,
      assistant: assistant,
    );

void main() {
  setUpAll(initGroupedClassL10n);

  Future<Navigated> pump(
    WidgetTester tester, {
    ClassMembersProgressResult? result,
  }) {
    return pumpGroupedApp(
      tester,
      user: counselorUser,
      home: const ClassMembersProgressView(
        clubId: 7,
        sectionId: 3,
        classId: 3,
        className: 'Explorador',
        yearId: 12,
      ),
      overrides: [
        classMembersProgressProvider(_query)
            .overrideWith((ref) async => result ?? _result()),
      ],
    );
  }

  List<String> memberOrder(WidgetTester tester) {
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('grouped-member-row-'),
    );
    return [
      for (final e in rows.evaluate())
        (e.widget.key! as ValueKey<String>)
            .value
            .replaceFirst('grouped-member-row-', ''),
    ];
  }

  testWidgets('summary: class average, legend and counselor cards',
      (tester) async {
    await pump(tester);

    final summary = find.byKey(const ValueKey('grouped-members-summary'));
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('35%', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('6 miembros', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('28 validados', findRichText: true),
      ),
      findsOneWidget,
    );

    // Counselor assigned, sub-counselor empty.
    final counselor = find.byKey(const ValueKey('grouped-counselor-card'));
    expect(find.descendant(of: counselor, matching: find.text('Mateo Herrera')),
        findsOneWidget);
    final assistant = find.byKey(const ValueKey('grouped-assistant-card'));
    expect(find.descendant(of: assistant, matching: find.text('Sin asignar')),
        findsOneWidget);
    expect(find.descendant(of: assistant, matching: find.text('Subconsejero')),
        findsOneWidget);
  });

  testWidgets('both roles empty say "Sin asignar" twice', (tester) async {
    await pump(tester, result: _result(counselor: null));
    expect(find.text('Sin asignar'), findsNWidgets(2));
  });

  testWidgets('members come lowest progress first', (tester) async {
    await pump(tester);
    expect(memberOrder(tester), ['l', 'i', 'x', 't', 'e', 'a']);
  });

  testWidgets('row says how many requirements are validated', (tester) async {
    await pump(tester);

    final row = find.byKey(const ValueKey('grouped-member-row-t'));
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining('5 de 12 requisitos validados',
            findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
        find.descendant(of: row, matching: find.text('45%')), findsOneWidget);
  });

  testWidgets('Atrasados keeps members under 40%', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('grouped-filter-behind')));
    await tester.pumpAndSettle();

    // 40% is not behind; 45% and up are out.
    expect(memberOrder(tester), ['l', 'i', 'x']);
  });

  testWidgets('Por corregir keeps members with rejected requirements',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('grouped-filter-fix')));
    await tester.pumpAndSettle();

    expect(memberOrder(tester), ['i', 't']);

    await tester.tap(find.byKey(const ValueKey('grouped-filter-all')));
    await tester.pumpAndSettle();
    expect(memberOrder(tester), hasLength(6));
  });

  testWidgets('a filter nobody passes says so', (tester) async {
    await pump(
      tester,
      result: _result(members: [_member('a', 'Valeria Torres', 92)]),
    );

    await tester.tap(find.byKey(const ValueKey('grouped-filter-behind')));
    await tester.pumpAndSettle();

    expect(find.text('Nadie en este filtro.'), findsOneWidget);
    expect(memberOrder(tester), isEmpty);
  });

  testWidgets('tapping a member opens their progress', (tester) async {
    final navigated = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('grouped-member-row-x')));
    await tester.pumpAndSettle();

    expect(navigated.last.path, '/home/grouped-class/class/3/member/x');
    expect(navigated.last.queryParameters['clubId'], '7');
    expect(navigated.last.queryParameters['sectionId'], '3');
    expect(navigated.last.queryParameters['className'], 'Explorador');
    expect(navigated.last.queryParameters['enrollmentId'], isNotEmpty);
  });

  testWidgets('empty class explains nobody is enrolled', (tester) async {
    await pump(tester, result: _result(members: const []));
    expect(find.text('Nadie cursa esta clase'), findsOneWidget);
    expect(find.textContaining('se inscriba a Explorador'), findsOneWidget);
  });

  group('filterAndSortMembers', () {
    test('sorts ascending and breaks ties by name', () {
      final sorted = filterAndSortMembers([
        _member('b', 'Bea', 50),
        _member('a', 'Ana', 50),
        _member('c', 'Cris', 10),
      ], GroupedMembersFilter.all);
      expect(sorted.map((m) => m.name), ['Cris', 'Ana', 'Bea']);
    });

    test('behind is strictly under 40', () {
      final behind = filterAndSortMembers([
        _member('a', 'A', 39),
        _member('b', 'B', 40),
      ], GroupedMembersFilter.behind);
      expect(behind.map((m) => m.name), ['A']);
    });
  });
}
