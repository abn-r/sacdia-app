import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_progress_summary.dart';
import 'package:sacdia_app/features/classes/domain/entities/progress_scope.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/teaching_scope_view.dart';
import 'package:sacdia_app/features/classes/presentation/widgets/grouped_class_skeleton.dart';

import '../grouped_class_test_support.dart';

const _query = TeachingScopeQuery(clubId: 7, sectionId: 3);

ProgressScopeClass _class(
  int id,
  String name,
  int members,
  int avg,
  List<int> dist, {
  String? counselor,
}) =>
    ProgressScopeClass(
      classId: id,
      name: name,
      clubTypeId: 2,
      accessLevel: 'section',
      membersCount: members,
      avgProgress: avg,
      statusCounts: RequirementStatusCounts(
        validated: dist[0],
        submitted: dist[1],
        rejected: dist[2],
        pending: dist[3],
      ),
      counselor: counselor == null
          ? null
          : ClassResponsible(userId: 'c$id', name: counselor),
    );

ProgressScopeResult _scope({
  String accessLevel = 'section',
  List<ProgressScopeClass>? classes,
}) =>
    ProgressScopeResult(
      clubSectionId: 3,
      clubTypeId: 2,
      ecclesiasticalYearId: 12,
      accessLevel: accessLevel,
      classes: classes ??
          [
            _class(1, 'Amigo', 9, 62, [3, 2, 1, 3], counselor: 'Laura Méndez'),
            _class(2, 'Compañero', 7, 48, [2, 1, 1, 3],
                counselor: 'Rubén Salas'),
            _class(3, 'Explorador', 8, 35, [1, 2, 2, 3],
                counselor: 'Mateo Herrera'),
            _class(4, 'Orientador', 5, 71, [3, 1, 0, 1],
                counselor: 'Andrea Luna'),
            _class(5, 'Viajero', 4, 20, [0, 1, 0, 3]),
            _class(6, 'Guía', 3, 88, [2, 1, 0, 0], counselor: 'Carlos Vega'),
          ],
    );

void main() {
  setUpAll(initGroupedClassL10n);

  Future<Navigated> pump(
    WidgetTester tester, {
    FutureOr<ProgressScopeResult> Function()? load,
    dynamic user,
  }) {
    return pumpGroupedApp(
      tester,
      user: user ?? directorUser,
      home: const TeachingScopeView(),
      overrides: [
        classProgressScopeProvider(_query)
            .overrideWith((ref) async => (load ?? _scope)()),
      ],
    );
  }

  testWidgets('director: whole-section banner, weighted average and counts',
      (tester) async {
    await pump(tester);

    final banner = find.byKey(const ValueKey('grouped-scope-banner'));
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining('todas las clases', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining('Conquistadores', findRichText: true),
      ),
      findsOneWidget,
    );

    final summary = find.byKey(const ValueKey('grouped-scope-summary'));
    // (62*9 + 48*7 + 35*8 + 71*5 + 20*4 + 88*3) / 36 = 52.03
    expect(
      find.descendant(
        of: summary,
        matching: find.textContaining('52%', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching:
            find.textContaining('36 miembros en 6 clases', findRichText: true),
      ),
      findsOneWidget,
    );
    // The legend adds up the four groups across every class.
    for (final label in [
      '11 validados',
      '8 en revisión',
      '4 por corregir',
      '13 sin enviar',
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
    // "Requisitos por corregir" is the sum of rejected.
    expect(
      find.descendant(
          of: summary, matching: find.text('Requisitos por corregir')),
      findsOneWidget,
    );
    expect(
        find.descendant(of: summary, matching: find.text('4')), findsOneWidget);
  });

  testWidgets('one row per class with members, counselor and percentage',
      (tester) async {
    await pump(tester);

    final amigo = find.byKey(const ValueKey('grouped-class-row-1'));
    expect(
      find.descendant(
        of: amigo,
        matching: find.textContaining('9 miembros · Consejero: Laura Méndez',
            findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
        find.descendant(of: amigo, matching: find.text('62%')), findsOneWidget);

    // A class with nobody in charge says so, in the error color.
    final viajero = find.byKey(const ValueKey('grouped-class-row-5'));
    final noCounselor = find.descendant(
      of: viajero,
      matching: find.textContaining('Sin consejero', findRichText: true),
    );
    expect(noCounselor, findsOneWidget);
    final rich = tester.widget<RichText>(
      find.descendant(
        of: viajero,
        matching: find.byWidgetPredicate(
          (w) =>
              w is RichText && w.text.toPlainText().contains('Sin consejero'),
        ),
      ),
    );
    Color? colorOf(String text) {
      Color? found;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == text) found = span.style?.color;
        return true;
      });
      return found;
    }

    expect(
      colorOf('Sin consejero'),
      const SacColors(Brightness.light).onErrorContainer,
    );
    // A class with a counselor keeps the secondary color.
    expect(colorOf('Consejero: Laura Méndez'), isNull);
  });

  testWidgets('counselor: only-my-classes banner and no assignment gear',
      (tester) async {
    await pump(
      tester,
      user: counselorUser,
      load: () => _scope(
        accessLevel: 'assigned',
        classes: [
          _class(1, 'Amigo', 9, 62, [3, 2, 1, 3], counselor: 'Laura Méndez'),
        ],
      ),
    );

    expect(
      find.textContaining('tus clases asignadas', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('todas las clases', findRichText: true),
        findsNothing);
    expect(find.byKey(const ValueKey('grouped-assign-button')), findsNothing);
  });

  testWidgets('director with club_roles permissions sees the gear',
      (tester) async {
    final navigated = await pump(tester);

    final gear = find.byKey(const ValueKey('grouped-assign-button'));
    expect(gear, findsOneWidget);
    await tester.tap(gear);
    await tester.pumpAndSettle();

    expect(navigated.last.path, '/home/grouped-class/assign');
    expect(navigated.last.queryParameters['yearId'], '12');
  });

  testWidgets('read-only role does not get the gear', (tester) async {
    await pump(tester, user: userWith(const ['club_roles:read']));
    expect(find.byKey(const ValueKey('grouped-assign-button')), findsNothing);
  });

  testWidgets('tapping a class opens its members with the context',
      (tester) async {
    final navigated = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('grouped-class-row-3')));
    await tester.pumpAndSettle();

    expect(navigated.last.path, '/home/grouped-class/class/3');
    expect(navigated.last.queryParameters, {
      'clubId': '7',
      'sectionId': '3',
      'yearId': '12',
      'className': 'Explorador',
    });
  });

  testWidgets('empty: the director is told classes appear on enrollment',
      (tester) async {
    await pump(tester, load: () => _scope(classes: const []));
    expect(find.text('Aún no hay clases en curso'), findsOneWidget);
    expect(find.textContaining('se inscriban a una clase'), findsOneWidget);
  });

  testWidgets('empty: the counselor is told to ask the director',
      (tester) async {
    await pump(
      tester,
      user: counselorUser,
      load: () => _scope(accessLevel: 'assigned', classes: const []),
    );
    expect(find.text('No tienes clases asignadas'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton, not a spinner', (tester) async {
    final never = Completer<ProgressScopeResult>();
    await pumpGroupedApp(
      settle: false,
      tester,
      user: directorUser,
      home: const TeachingScopeView(),
      overrides: [
        classProgressScopeProvider(_query).overrideWith((ref) => never.future),
      ],
    );

    expect(find.byType(GroupedClassSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error shows a translated message and retries', (tester) async {
    var calls = 0;
    await pump(
      tester,
      load: () {
        calls++;
        if (calls == 1) throw ConnectionException(message: 'raw');
        return _scope();
      },
    );

    expect(find.text('No pudimos cargar el avance'), findsOneWidget);
    expect(find.textContaining('raw'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('grouped-class-row-1')), findsOneWidget);
  });
}
