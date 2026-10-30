/// Tests for the redesigned EvidenceReviewListView ("Evidencias").
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_age.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/evidence_review_list_view.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/evidence_review_card.dart';

import '../../coordinator_test_harness.dart';
import '../../../../support/riverpod_test_support.dart';

EvidenceReviewItem _item(
  String id,
  String name, {
  int daysAgo = 1,
  EvidenceReviewType type = EvidenceReviewType.classType,
  int files = 2,
  bool deleted = false,
  String? context = 'Amigo · Requisito 1',
  String? club = 'Club Orión · Conquistadores',
}) =>
    EvidenceReviewItem(
      id: id,
      type: type,
      status: EvidenceReviewStatus.pending,
      memberName: name,
      memberIsDeleted: deleted,
      context: context,
      clubSectionLabel: club,
      submittedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      fileCount: files,
    );

/// Deliberately unsorted.
final _items = [
  _item('a', 'Ana Reciente', daysAgo: 0),
  _item('b', 'Beto Vencido', daysAgo: 20, type: EvidenceReviewType.honor),
  _item('c', 'Carla Atención', daysAgo: 5, files: 1),
  _item('d', 'Diego Normal', daysAgo: 2),
];

/// [_items] as the server filters them.
List<EvidenceReviewItem> _byType(EvidenceReviewType? type) =>
    type == null ? _items : _items.where((i) => i.type == type).toList();

/// [count] class evidences, oldest first: 'M 0' is the oldest.
List<EvidenceReviewItem> _queue(int count) => [
      for (var i = 0; i < count; i++) _item('$i', 'M $i', daysAgo: count - i),
    ];

/// Pumps the list with a queue that fits in one page per filter.
Future<void> _pumpList(
  WidgetTester tester,
  FutureOr<List<EvidenceReviewItem>> Function(EvidenceReviewType? type) load, {
  EvidenceReviewType? initialFilter,
  int overdueDays = kEvidenceOverdueDays,
}) =>
    _pumpPaged(
      tester,
      (type, page) async => singlePage(await load(type)),
      initialFilter: initialFilter,
      overdueDays: overdueDays,
    );

Future<void> _pumpPaged(
  WidgetTester tester,
  PendingPageLoader loader, {
  EvidenceReviewType? initialFilter,
  Size size = const Size(800, 2600),
  int overdueDays = kEvidenceOverdueDays,
}) async {
  useTallSurface(tester, size: size);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const EvidenceReviewListView()),
      GoRoute(
        path: '/coordinator/evidence-review/:type/:id',
        builder: (_, state) => Text(
          'page:detail:${state.pathParameters['type']}:'
          '${state.pathParameters['id']}',
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        if (initialFilter != null)
          evidenceTypeFilterProvider.overrideWith((ref) => initialFilter),
        pendingEvidenceOverride(loader),
        evidenceOverdueDaysProvider.overrideWith((ref) => overdueDays),
      ],
      child: localized((context) => localizedRouterApp(context, router)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('data', () {
    testWidgets('frosted top bar, no refresh button, oldest-first caption',
        (tester) async {
      await _pumpList(tester, (_) => _items);

      final bar = tester.widget<SacTopBar>(find.byType(SacTopBar));
      expect(bar.frosted, isTrue);
      expect(bar.title, 'Evidencias');
      expect(bar.actions, isEmpty);
      expect(find.byType(IconButton), findsNothing);
      expect(find.text('Más antiguas primero'), findsOneWidget);
    });

    testWidgets('renders the oldest evidence first', (tester) async {
      await _pumpList(tester, (_) => _items);

      double y(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(y('Beto Vencido'), lessThan(y('Carla Atención')));
      expect(y('Carla Atención'), lessThan(y('Diego Normal')));
      expect(y('Diego Normal'), lessThan(y('Ana Reciente')));
    });

    testWidgets('age badge: overdue (error), warning and neutral',
        (tester) async {
      await _pumpList(tester, (_) => _items);

      SacBadge badge(String label) =>
          tester.widget<SacBadge>(find.widgetWithText(SacBadge, label));

      expect(badge('Vencida · 20 d').variant, SacBadgeVariant.error);
      expect(badge('Hace 5 d').variant, SacBadgeVariant.accent);
      expect(badge('Hace 2 d').variant, SacBadgeVariant.neutral);
      expect(badge('Hoy').variant, SacBadgeVariant.neutral);
    });

    testWidgets('age badge follows the backend overdue threshold',
        (tester) async {
      await _pumpList(tester, (_) => _items, overdueDays: 30);

      SacBadge badge(String label) =>
          tester.widget<SacBadge>(find.widgetWithText(SacBadge, label));

      expect(find.text('Vencida · 20 d'), findsNothing);
      expect(badge('Hace 20 d').variant, SacBadgeVariant.accent);
    });

    testWidgets('card shows member, context, club, type and attachments',
        (tester) async {
      await _pumpList(tester, (_) => [_items[1], _items[2]]);

      expect(find.text('Beto Vencido'), findsOneWidget);
      expect(find.text('Amigo · Requisito 1'), findsNWidgets(2));
      expect(find.text('Club Orión · Conquistadores'), findsNWidgets(2));
      // Type badges.
      expect(find.widgetWithText(SacBadge, 'Especialidad'), findsOneWidget);
      expect(find.widgetWithText(SacBadge, 'Clase'), findsOneWidget);
      // Attachment count, singular and plural.
      expect(find.text('2 archivos'), findsOneWidget);
      expect(find.text('1 archivo'), findsOneWidget);
      expect(find.byType(EvidenceReviewCard), findsNWidgets(2));
    });

    testWidgets('a deleted member renders muted without a photo',
        (tester) async {
      await _pumpList(
        tester,
        (_) => [_item('x', 'Nombre Real', deleted: true)],
      );

      expect(find.text('Cuenta eliminada'), findsOneWidget);
      expect(find.text('Nombre Real'), findsNothing);
    });

    testWidgets('tapping a card opens the evidence detail', (tester) async {
      await _pumpList(tester, (_) => [_item('77', 'Ana Tocada')]);

      await tester.tap(find.text('Ana Tocada'));
      await tester.pumpAndSettle();

      expect(find.text('page:detail:class:77'), findsOneWidget);
    });
  });

  group('filters', () {
    List<int?> counts(WidgetTester tester) => tester
        .widgetList<SacFilterChip>(find.byType(SacFilterChip))
        .map((chip) => chip.count)
        .toList();

    testWidgets('shows All / Classes / Honors chips with real counts',
        (tester) async {
      await _pumpList(tester, _byType);

      expect(find.widgetWithText(SacFilterChip, 'Todas'), findsOneWidget);
      expect(find.widgetWithText(SacFilterChip, 'Clases'), findsOneWidget);
      expect(
        find.widgetWithText(SacFilterChip, 'Especialidades'),
        findsOneWidget,
      );
      // 4 loaded: 3 classes and 1 honor.
      expect(counts(tester), [4, 3, 1]);
    });

    testWidgets('counts are the server totals, not the loaded page',
        (tester) async {
      const totals = {
        null: 57,
        EvidenceReviewType.classType: 40,
        EvidenceReviewType.honor: 17,
      };
      await _pumpPaged(
        tester,
        (type, page) => EvidenceReviewPage(
          items: _queue(20),
          total: totals[type],
          page: page,
          limit: kPendingEvidencePageSize,
        ),
      );

      expect(counts(tester), [57, 40, 17]);
    });

    testWidgets('omits a count the server did not report', (tester) async {
      await _pumpPaged(
        tester,
        (type, page) => EvidenceReviewPage(
          items: _byType(type),
          total: type == EvidenceReviewType.honor ? null : _byType(type).length,
          page: 1,
          limit: kPendingEvidencePageSize,
        ),
      );

      expect(counts(tester), [4, 3, null]);
    });

    testWidgets('selecting a type asks the provider for that type',
        (tester) async {
      final requested = <EvidenceReviewType?>[];
      await _pumpList(tester, (type) {
        requested.add(type);
        return type == EvidenceReviewType.honor ? [_items[1]] : _items;
      });

      await tester.tap(find.widgetWithText(SacFilterChip, 'Especialidades'));
      await tester.pumpAndSettle();

      expect(requested, contains(EvidenceReviewType.honor));
      expect(find.byType(EvidenceReviewCard), findsOneWidget);
      expect(find.text('Beto Vencido'), findsOneWidget);
      final selected = tester
          .widgetList<SacFilterChip>(find.byType(SacFilterChip))
          .singleWhere((chip) => chip.selected);
      expect(selected.label, 'Especialidades');
    });
  });

  group('pagination', () {
    Finder queueScrollable() => find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> scrollToEnd(WidgetTester tester) async {
      await tester.fling(queueScrollable(), const Offset(0, -20000), 5000);
      await tester.pump();
    }

    testWidgets('loads every page while scrolling, oldest first',
        (tester) async {
      final all = _queue(45);
      final requested = <int>[];
      await _pumpPaged(
        tester,
        (type, page) {
          if (type == null) requested.add(page);
          return pageOf(all, page);
        },
        size: const Size(800, 1200),
      );

      expect(requested, [1]);
      expect(find.text('M 0'), findsOneWidget);

      for (var i = 0; i < 4 && !requested.contains(3); i++) {
        await scrollToEnd(tester);
        await tester.pumpAndSettle();
      }
      await scrollToEnd(tester);
      await tester.pumpAndSettle();

      expect(requested, [1, 2, 3]);
      expect(find.text('M 44'), findsOneWidget);
      // Last page reached: no footer left.
      expect(find.byType(SacLoadingSmall), findsNothing);
    });

    testWidgets('shows the small loader while the next page loads',
        (tester) async {
      final all = _queue(30);
      final second = Completer<EvidenceReviewPage>();
      await _pumpPaged(
        tester,
        (type, page) => page == 1 ? pageOf(all, 1) : second.future,
        size: const Size(800, 1200),
      );

      await scrollToEnd(tester);
      await tester.pump();
      expect(find.byType(SacLoadingSmall), findsOneWidget);
      expect(find.text('M 29'), findsNothing);

      second.complete(pageOf(all, 2));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);
      await tester.pumpAndSettle();

      expect(find.byType(SacLoadingSmall), findsNothing);
      expect(find.text('M 29'), findsOneWidget);
    });

    testWidgets('a failed page keeps the list and offers a retry',
        (tester) async {
      final all = _queue(30);
      var failSecond = true;
      await _pumpPaged(
        tester,
        (type, page) {
          if (page == 2 && failSecond) throw Exception('boom');
          return pageOf(all, page);
        },
        size: const Size(800, 1200),
      );

      await scrollToEnd(tester);
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar más evidencias.'), findsOneWidget);
      expect(find.byType(SacErrorState), findsNothing);
      expect(find.text('M 19'), findsOneWidget);

      failSecond = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar más evidencias.'), findsNothing);
      expect(find.text('M 29'), findsOneWidget);
    });

    testWidgets('a queue that fits in one page has no footer', (tester) async {
      await _pumpList(tester, (_) => _items);

      expect(find.byType(SacLoadingSmall), findsNothing);
    });
  });

  group('states', () {
    testWidgets('loading shows four card skeletons, no data and no error',
        (tester) async {
      final never = Completer<EvidenceReviewPage>();
      useTallSurface(tester);
      await tester.pumpWidget(
        testProviderScope(
          overrides: [
            pendingEvidenceOverride((type, page) => never.future),
          ],
          child: localized(
            (context) => localizedApp(context, const EvidenceReviewListView()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SacCard), findsNWidgets(4));
      expect(find.byType(EvidenceReviewCard), findsNothing);
      expect(find.byType(SacErrorState), findsNothing);
      expect(find.byType(SacEmptyState), findsNothing);

      never.complete(singlePage(const []));
      await tester.pumpAndSettle();
    });

    testWidgets('empty queue says everything is up to date', (tester) async {
      await _pumpList(tester, (_) => const []);

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.text('Todo al día'), findsOneWidget);
      expect(
        find.text('No hay evidencias pendientes de revisión.'),
        findsOneWidget,
      );
      expect(find.text('Más antiguas primero'), findsNothing);
    });

    testWidgets('empty with a filter uses different copy', (tester) async {
      await _pumpList(
        tester,
        (_) => const [],
        initialFilter: EvidenceReviewType.honor,
      );

      expect(find.text('Sin evidencias pendientes'), findsOneWidget);
      expect(
        find.text(
          'No hay evidencias de este tipo por revisar. Prueba con otro filtro.',
        ),
        findsOneWidget,
      );
      expect(find.text('Todo al día'), findsNothing);
      // The chips stay so the filter can be changed.
      expect(find.byType(SacFilterChip), findsNWidgets(3));
    });

    testWidgets('a load failure shows a localized retryable error',
        (tester) async {
      var calls = 0;
      await _pumpList(tester, (_) {
        calls++;
        throw Exception('Exception: boom 500 RBAC');
      });

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('No pudimos cargar las evidencias'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);

      final before = calls;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(before));
    });

    testWidgets('a 403 shows the access-restricted state without retry',
        (tester) async {
      await _pumpList(
        tester,
        (_) => throw const CoordinatorLoadException(
          'No tienes permiso',
          isForbidden: true,
        ),
      );

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('Acceso restringido'), findsOneWidget);
      final icon = tester.widget<HugeIcon>(
        find.descendant(
          of: find.byType(SacErrorState),
          matching: find.byType(HugeIcon),
        ),
      );
      expect(icon.icon, HugeIcons.strokeRoundedLockKey);
      expect(find.text('Reintentar'), findsNothing);
    });
  });
}
