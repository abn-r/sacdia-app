import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/widgets/members_filter_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/riverpod_test_support.dart';

const _members = [
  ClubMember(
    userId: 'm1',
    name: 'Ana',
    currentClass: 'Amigo',
    clubRole: 'director',
  ),
  ClubMember(
    userId: 'm2',
    name: 'Beto',
    currentClass: 'Amigo',
    isEnrolled: false,
  ),
  ClubMember(userId: 'm3', name: 'Carla', currentClass: 'Compañero'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    List<String> classes = const ['Amigo', 'Sin clase', 'Guías Mayores'],
    List<ClubMember> members = _members,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          membersNotifierProvider.overrideWith(
            () => _FixedMembersNotifier(MembersData(members: members)),
          ),
          availableClassesProvider.overrideWith((ref) => classes),
          availableRolesProvider.overrideWith((ref) => const ['director']),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          assetLoader: _TestAssetLoader(translations),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: const Scaffold(body: MembersFilterBar()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MembersFilterBar)));

  MemberFilters filtersOf(WidgetTester tester) =>
      containerOf(tester).read(memberFiltersProvider);

  Finder filterButton() => find.bySemanticsLabel(RegExp(r'^Filtros'));

  Future<void> openSheetFromButton(WidgetTester tester) async {
    await tester.tap(filterButton());
    await tester.pumpAndSettle();
  }

  group('MembersFilterBar', () {
    testWidgets('should show the search field and the filter button only', (
      tester,
    ) async {
      await pumpBar(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(filterButton(), findsOneWidget);
      expect(find.byType(SacFilterChip), findsNothing);
    });

    testWidgets('should open one sheet with logos on class chips', (
      tester,
    ) async {
      await pumpBar(tester);
      await openSheetFromButton(tester);

      expect(find.text('Filtrar miembros'), findsOneWidget);
      expect(find.text('CLASE'), findsOneWidget);
      expect(find.text('CARGO'), findsOneWidget);
      expect(find.text('INSCRIPCIÓN'), findsOneWidget);

      final amigo = tester.widget<Image>(
        find.byKey(const ValueKey('member-filter-class-logo-Amigo')),
      );
      expect(
        _assetName(amigo),
        'assets/img/logos-clases/CQ-01.png',
      );
      expect(amigo.width, 20);
      expect(amigo.height, 20);

      final guias = tester.widget<Image>(
        find.byKey(const ValueKey('member-filter-class-logo-Guías Mayores')),
      );
      expect(
        _assetName(guias),
        ClubType.guiasMayores.logoAsset,
      );

      expect(
        find.byKey(const ValueKey('member-filter-class-logo-Sin clase')),
        findsNothing,
      );
      expect(find.text('Sin clase'), findsOneWidget);
      expect(find.text('Director'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Inscrito'), findsOneWidget);
      expect(find.text('No inscrito'), findsOneWidget);
    });

    testWidgets('should list classes by catalog id instead of name', (
      tester,
    ) async {
      await pumpBar(
        tester,
        classes: const [
          'Amigo',
          'Compañero',
          'Explorador',
          'Guía',
          'Guías Mayores',
          'Orientador',
          'Sin clase',
          'Viajero',
        ],
        members: const [
          ClubMember(
            userId: 'guia',
            name: 'Guía',
            currentClass: 'Guía',
            currentClassId: 6,
          ),
          ClubMember(
            userId: 'amigo-alto',
            name: 'Amigo',
            currentClass: 'Amigo',
            currentClassId: 9,
          ),
          ClubMember(
            userId: 'viajero',
            name: 'Viajero',
            currentClass: 'Viajero',
            currentClassId: 5,
          ),
          ClubMember(
            userId: 'orientador',
            name: 'Orientador',
            currentClass: 'Orientador',
            currentClassId: 4,
          ),
          ClubMember(
            userId: 'explorador',
            name: 'Explorador',
            currentClass: 'Explorador',
            currentClassId: 3,
          ),
          ClubMember(
            userId: 'companero',
            name: 'Compañero',
            currentClass: 'Compañero',
            currentClassId: 2,
          ),
          ClubMember(
            userId: 'amigo',
            name: 'Amigo',
            currentClass: 'Amigo',
            currentClassId: 1,
          ),
        ],
      );
      await openSheetFromButton(tester);

      final labels = tester
          .widgetList<SacFilterChip>(find.byType(SacFilterChip))
          .map((chip) => chip.label)
          .take(8)
          .toList();

      expect(labels, [
        'Amigo',
        'Compañero',
        'Explorador',
        'Orientador',
        'Viajero',
        'Guía',
        'Guías Mayores',
        'Sin clase',
      ]);
    });

    testWidgets('should update the count live as the draft changes', (
      tester,
    ) async {
      await pumpBar(tester);
      await openSheetFromButton(tester);

      expect(find.text('Ver 3 miembros'), findsOneWidget);

      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();
      expect(find.text('Ver 2 miembros'), findsOneWidget);

      await tester.tap(find.text('Inscrito'));
      await tester.pumpAndSettle();
      expect(find.text('Ver 1 miembro'), findsOneWidget);

      await tester.tap(find.text('Director'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No inscrito'));
      await tester.pumpAndSettle();
      expect(find.text('Ver 0 miembros'), findsOneWidget);

      // Nothing is applied while the sheet is open.
      expect(filtersOf(tester).hasActiveFilters, isFalse);
    });

    testWidgets('should deselect a selected chip when tapped again', (
      tester,
    ) async {
      await pumpBar(tester);
      await openSheetFromButton(tester);

      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();
      expect(find.text('Ver 2 miembros'), findsOneWidget);

      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();
      expect(find.text('Ver 3 miembros'), findsOneWidget);
    });

    testWidgets('should apply the draft with the confirm button', (
      tester,
    ) async {
      await pumpBar(tester);
      await openSheetFromButton(tester);

      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Director'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver 1 miembro'));
      await tester.pumpAndSettle();

      expect(find.text('Filtrar miembros'), findsNothing);
      final filters = filtersOf(tester);
      expect(filters.classFilter, 'Amigo');
      expect(filters.roleFilter, 'director');
      expect(filters.enrolledFilter, isNull);
    });

    testWidgets('should keep the search text when applying', (tester) async {
      await pumpBar(tester);
      await tester.enterText(find.byType(TextField), 'an');
      await tester.pump();

      await openSheetFromButton(tester);
      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();
      expect(find.text('Ver 1 miembro'), findsOneWidget);
      await tester.tap(find.text('Ver 1 miembro'));
      await tester.pumpAndSettle();

      final filters = filtersOf(tester);
      expect(filters.searchQuery, 'an');
      expect(filters.classFilter, 'Amigo');
    });

    testWidgets('should reset only the draft with Limpiar', (tester) async {
      await pumpBar(tester);
      containerOf(tester).read(memberFiltersProvider.notifier).state =
          const MemberFilters(classFilter: 'Amigo', enrolledFilter: true);
      await tester.pump();

      await openSheetFromButton(tester);
      expect(find.text('Ver 1 miembro'), findsOneWidget);

      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();

      expect(find.text('Filtrar miembros'), findsOneWidget);
      expect(find.text('Ver 3 miembros'), findsOneWidget);
      // The applied filters stay until the user confirms.
      expect(filtersOf(tester).classFilter, 'Amigo');

      await tester.tap(find.text('Ver 3 miembros'));
      await tester.pumpAndSettle();
      expect(filtersOf(tester).hasActiveFilters, isFalse);
    });

    testWidgets('should discard the draft when dismissed', (tester) async {
      await pumpBar(tester);
      await openSheetFromButton(tester);

      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();

      // Tap the scrim above the sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Filtrar miembros'), findsNothing);
      expect(filtersOf(tester).hasActiveFilters, isFalse);
    });

    testWidgets('should show the badge with the active filter count', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(find.text('1'), findsNothing);

      final notifier = containerOf(tester).read(memberFiltersProvider.notifier);
      notifier.state = const MemberFilters(classFilter: 'Amigo');
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      notifier.state = const MemberFilters(
        classFilter: 'Amigo',
        roleFilter: 'director',
        enrolledFilter: false,
      );
      await tester.pump();
      expect(find.text('3'), findsOneWidget);

      // The search does not count.
      notifier.state = const MemberFilters(searchQuery: 'ana');
      await tester.pump();
      expect(find.text('1'), findsNothing);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('should clear the search field on an external reset', (
      tester,
    ) async {
      await pumpBar(tester);
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pump();
      expect(filtersOf(tester).searchQuery, 'ana');

      containerOf(tester).read(memberFiltersProvider.notifier).state =
          const MemberFilters();
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  });
}

/// Asset of an [Image], looking through the chip's cache-size wrapper.
String _assetName(Image image) {
  final provider = image.image;
  final inner = provider is ResizeImage ? provider.imageProvider : provider;
  return (inner as AssetImage).assetName;
}

class _FixedMembersNotifier extends MembersNotifier {
  _FixedMembersNotifier(this._data);

  final MembersData _data;

  @override
  Future<MembersData> build() async => _data;
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}
