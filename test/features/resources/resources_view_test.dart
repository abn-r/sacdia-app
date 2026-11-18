import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/features/resources/domain/entities/resource_category.dart';
import 'package:sacdia_app/features/resources/presentation/providers/resources_providers.dart';
import 'package:sacdia_app/features/resources/presentation/views/resources_view.dart';
import 'package:sacdia_app/features/resources/presentation/widgets/resource_grid_skeleton.dart';

import '../../support/l10n_test_support.dart';
import '../../support/riverpod_test_support.dart';
import 'resources_test_support.dart';

const _clases = ResourceCategory(resourceCategoryId: 1, name: 'Clases');
const _himnos = ResourceCategory(resourceCategoryId: 2, name: 'Himnos');

FakeResourcesRepository _library({Completer<void>? gate}) {
  return FakeResourcesRepository(
    gate: gate,
    categories: const [_clases, _himnos],
    resources: [
      testResource(
          id: 'a',
          title: 'Manual Amigo',
          categoryId: 1,
          categoryName: 'Clases'),
      testResource(
          id: 'b',
          title: 'Manual Compañero',
          categoryId: 1,
          categoryName: 'Clases'),
      testResource(
          id: 'c',
          title: 'Himno Conquistadores',
          type: 'audio',
          categoryId: 2,
          categoryName: 'Himnos'),
      testResource(
          id: 'd',
          title: 'Guía de nudos',
          categoryId: 2,
          categoryName: 'Himnos'),
    ],
  );
}

Future<void> _pumpView(
    WidgetTester tester, FakeResourcesRepository repo) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testProviderScope(
      overrides: [resourcesRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true, size: Size(900, 1800)),
          child: ResourcesView(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSpanishTranslations);

  group('category chips', () {
    testWidgets('show counts and filter together with the type',
        (tester) async {
      final repo = _library();
      await _pumpView(tester, repo);

      // Both categories with their counts.
      for (final name in ['Clases', 'Himnos']) {
        expect(
          find.descendant(
            of: find.widgetWithText(SacFilterChip, name),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Manual Amigo'), findsOneWidget);
      expect(find.text('Himno Conquistadores'), findsOneWidget);

      await tester.tap(find.widgetWithText(SacFilterChip, 'Himnos'));
      await tester.pumpAndSettle();
      expect(repo.gridCalls.last.categoryId, 2);
      expect(find.text('Manual Amigo'), findsNothing);
      expect(find.text('Guía de nudos'), findsOneWidget);

      // Type + category combine: audio inside Himnos.
      await tester.tap(find.widgetWithText(SacFilterChip, 'Audio'));
      await tester.pumpAndSettle();
      expect(repo.gridCalls.last.type, 'audio');
      expect(repo.gridCalls.last.categoryId, 2);
      expect(find.text('Himno Conquistadores'), findsOneWidget);
      expect(find.text('Guía de nudos'), findsNothing);

      // Tapping the selected category clears it.
      await tester.tap(find.widgetWithText(SacFilterChip, 'Himnos'));
      await tester.pumpAndSettle();
      expect(repo.gridCalls.last.categoryId, isNull);
      expect(repo.gridCalls.last.type, 'audio');
    });

    testWidgets('still show when /resource-categories is forbidden',
        (tester) async {
      final repo = FakeResourcesRepository(
        categoriesForbidden: true,
        resources: _library().resources,
      );
      await _pumpView(tester, repo);

      for (final name in ['Clases', 'Himnos']) {
        expect(
          find.descendant(
            of: find.widgetWithText(SacFilterChip, name),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('are hidden when the library has no categories',
        (tester) async {
      final repo = FakeResourcesRepository(
        resources: [testResource(id: 'a', title: 'Manual Amigo')],
      );
      await _pumpView(tester, repo);

      expect(find.byType(SacFilterChip), findsNWidgets(6)); // type chips only
    });
  });

  group('empty states', () {
    testWidgets('search with no hits in a type offers to see all types',
        (tester) async {
      final repo = _library();
      await _pumpView(tester, repo);

      await tester.tap(find.widgetWithText(SacFilterChip, 'Audio'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nudos');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // The query is repeated and other types are known to have a match.
      expect(find.text('No hay audio para «nudos»'), findsOneWidget);
      expect(find.text('Hay 1 en otros tipos.'), findsOneWidget);

      await tester.tap(find.text('Ver en todos los tipos'));
      await tester.pumpAndSettle();

      expect(repo.gridCalls.last.type, isNull);
      expect(repo.gridCalls.last.search, 'nudos');
      expect(find.text('Guía de nudos'), findsOneWidget);
    });

    testWidgets('search with no hits anywhere offers to clear the search',
        (tester) async {
      await _pumpView(tester, _library());

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados para «zzz»'), findsOneWidget);
      await tester.tap(find.text('Borrar búsqueda'));
      await tester.pumpAndSettle();

      expect(find.text('Manual Amigo'), findsOneWidget);
    });

    testWidgets('a club without resources says so and offers a refresh',
        (tester) async {
      final repo = FakeResourcesRepository();
      await _pumpView(tester, repo);

      expect(find.text('Aún no hay recursos'), findsOneWidget);
      expect(find.textContaining('El campo local publica'), findsOneWidget);
      final before = repo.gridCalls.length;

      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();

      expect(repo.gridCalls.length, greaterThan(before));
    });
  });

  group('loading', () {
    testWidgets('shows a skeleton shaped like the grid, not a spinner',
        (tester) async {
      final gate = Completer<void>();
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testProviderScope(
          overrides: [
            resourcesRepositoryProvider.overrideWithValue(_library(gate: gate)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ResourcesView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ResourceGridSkeleton), findsOneWidget);
      expect(find.byType(ResourceCardSkeleton), findsNWidgets(6));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      gate.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.byType(ResourceGridSkeleton), findsNothing);
      expect(find.text('Manual Amigo'), findsOneWidget);
    });
  });
}
