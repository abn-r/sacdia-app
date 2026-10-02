import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/widgets/members_filter_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    List<ClubMember> members = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
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

  double viewHeight(WidgetTester tester) {
    return tester.view.physicalSize.height / tester.view.devicePixelRatio;
  }

  void expectHalfSheet(WidgetTester tester) {
    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.expand, isFalse);
    expect(sheet.initialChildSize, 0.5);
    expect(sheet.minChildSize, 0.45);
    expect(sheet.maxChildSize, 0.92);

    final height = tester.getSize(find.byType(DraggableScrollableSheet)).height;
    expect(height, closeTo(viewHeight(tester) * 0.5, 2));
  }

  group('MembersFilterBar', () {
    testWidgets(
      'should open the class sheet at half height with logos',
      (tester) async {
        await pumpBar(tester);
        await tester.tap(find.text('Clase'));
        await tester.pumpAndSettle();

        expect(find.text('Filtrar por clase'), findsOneWidget);
        expectHalfSheet(tester);

        final amigo = tester.widget<Image>(
          find.byKey(const ValueKey('member-filter-class-logo-Amigo')),
        );
        expect(
          (amigo.image as AssetImage).assetName,
          'assets/img/logos-clases/CQ-01.png',
        );
        expect(amigo.width, 24);
        expect(amigo.height, 24);

        final guias = tester.widget<Image>(
          find.byKey(const ValueKey('member-filter-class-logo-Guías Mayores')),
        );
        expect(
          (guias.image as AssetImage).assetName,
          ClubType.guiasMayores.logoAsset,
        );

        expect(
          find.byKey(const ValueKey('member-filter-class-logo-Sin clase')),
          findsNothing,
        );
        expect(find.text('Sin clase'), findsOneWidget);

        final before =
            tester.getSize(find.byType(DraggableScrollableSheet)).height;
        await tester.drag(find.text('Amigo'), const Offset(0, -220));
        await tester.pumpAndSettle();

        final after =
            tester.getSize(find.byType(DraggableScrollableSheet)).height;
        expect(after, greaterThan(before + 40));
        expect(after, lessThan(viewHeight(tester) * 0.95));
        expect(find.text('Filtrar por clase'), findsOneWidget);
      },
    );

    testWidgets(
      'should list classes by catalog id instead of name',
      (tester) async {
        tester.view.physicalSize = const Size(400, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
        await tester.tap(find.text('Clase'));
        await tester.pumpAndSettle();

        final labels = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((tile) => (tile.title! as Text).data)
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
      },
    );

    testWidgets('should keep filtering when a class is selected', (
      tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.text('Clase'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Amigo'));
      await tester.pumpAndSettle();

      expect(find.text('Filtrar por clase'), findsNothing);
      expect(find.text('Amigo'), findsOneWidget);
      expect(find.text('Clase'), findsNothing);
    });

    testWidgets(
      'should open the role sheet at the same size without logos',
      (tester) async {
        await pumpBar(tester);
        await tester.tap(find.text('Cargo'));
        await tester.pumpAndSettle();

        expect(find.text('Filtrar por cargo'), findsOneWidget);
        expect(find.text('Director'), findsOneWidget);
        expectHalfSheet(tester);
        expect(find.byType(Image), findsNothing);
        expect(
          find.byKey(const ValueKey('member-filter-class-logo-director')),
          findsNothing,
        );
      },
    );
  });
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
