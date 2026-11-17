import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart' hide Unit;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/domain/repositories/members_repository.dart';
import 'package:sacdia_app/features/members/domain/usecases/get_club_members.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/units/domain/entities/unit.dart';
import 'package:sacdia_app/features/units/domain/entities/unit_member.dart';
import 'package:sacdia_app/features/units/domain/repositories/units_repository.dart';
import 'package:sacdia_app/features/units/domain/usecases/get_unit_detail.dart';
import 'package:sacdia_app/features/units/presentation/providers/units_providers.dart';
import 'package:sacdia_app/features/units/presentation/views/unit_form_view.dart';
import 'package:sacdia_app/features/units/presentation/widgets/unit_form_rows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/riverpod_test_support.dart';

class _FakeMembersRepository extends Fake implements MembersRepository {}

class _FakeUnitsRepository extends Fake implements UnitsRepository {}

class _FakeGetClubMembers extends GetClubMembers {
  _FakeGetClubMembers(this.members) : super(_FakeMembersRepository());

  final List<ClubMember> members;

  @override
  Future<Either<Failure, List<ClubMember>>> call(
    GetClubMembersParams params, {
    cancelToken,
  }) async =>
      Right(members);
}

class _FakeGetUnitDetail extends GetUnitDetail {
  _FakeGetUnitDetail(this.unit) : super(_FakeUnitsRepository());

  final Unit unit;

  @override
  Future<Either<Failure, Unit>> call(
    GetUnitDetailParams params, {
    cancelToken,
  }) async =>
      Right(unit);
}

class _RecordingUnitsNotifier extends UnitsNotifier {
  Map<String, Object?>? created;
  Map<String, Object?>? updated;

  @override
  UnitsState build() => const UnitsState(units: []);

  @override
  Future<bool> createUnit({
    required String name,
    required String captainId,
    required String secretaryId,
    required String advisorId,
    String? substituteAdvisorId,
    required int clubTypeId,
    int? clubSectionId,
    List<String> memberUserIds = const [],
  }) async {
    created = {
      'name': name,
      'captainId': captainId,
      'secretaryId': secretaryId,
      'advisorId': advisorId,
      'substituteAdvisorId': substituteAdvisorId,
      'clubTypeId': clubTypeId,
      'clubSectionId': clubSectionId,
      'memberUserIds': memberUserIds,
    };
    return true;
  }

  @override
  Future<bool> updateUnit({
    required int unitId,
    String? name,
    String? captainId,
    String? secretaryId,
    String? advisorId,
    String? substituteAdvisorId,
    int? clubTypeId,
    int? clubSectionId,
    List<String>? memberUserIds,
  }) async {
    updated = {
      'unitId': unitId,
      'name': name,
      'captainId': captainId,
      'secretaryId': secretaryId,
      'advisorId': advisorId,
      'substituteAdvisorId': substituteAdvisorId,
      'memberUserIds': memberUserIds,
    };
    return true;
  }
}

ClubMember _m(String id, String name, String surname) =>
    ClubMember(userId: id, name: name, paternalSurname: surname);

final _people = <ClubMember>[
  _m('u1', 'Ana', 'Castillo'),
  _m('u2', 'Bruno', 'Díaz'),
  _m('u3', 'Carla', 'Méndez'),
  _m('u4', 'Diego', 'Paredes'),
  _m('u5', 'Elena', 'Ruiz'),
  _m('u6', 'Felipe', 'Soto'),
  _m('u7', 'Gala', 'Torres'),
  _m('u8', 'Hugo', 'Vera'),
  _m('u9', 'Irene', 'Wong'),
];

UnitMember _um(String id, String name, String surname) =>
    UnitMember(id: id, name: name, surname: surname);

/// Existing unit: Ana captain, Bruno secretary, Carla advisor, and Diego,
/// Elena, Felipe, Gala, Hugo as members.
const _editUnit = Unit(
  id: 7,
  name: 'Halcones',
  type: 'Conquistadores',
  memberCount: 5,
  clubSectionId: 2,
  captainId: 'u1',
  secretaryId: 'u2',
  advisorId: 'u3',
);

Unit _editDetail() => Unit(
      id: 7,
      name: 'Halcones',
      type: 'Conquistadores',
      memberCount: 5,
      clubSectionId: 2,
      captainId: 'u1',
      secretaryId: 'u2',
      advisorId: 'u3',
      members: [
        _um('u4', 'Diego', 'Paredes'),
        _um('u5', 'Elena', 'Ruiz'),
        _um('u6', 'Felipe', 'Soto'),
        _um('u7', 'Gala', 'Torres'),
        _um('u8', 'Hugo', 'Vera'),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('crear', () {
    testWidgets('pantalla completa con el título y la acción Crear',
        (tester) async {
      final h = await _open(tester);

      expect(find.byType(UnitFormView), findsOneWidget);
      expect(find.text('Nueva unidad'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.byKey(const ValueKey('unit-form-save')), findsOneWidget);
      expect(find.text('Crear'), findsOneWidget);
      expect(find.text('RESPONSABLES'), findsOneWidget);
      expect(find.text('MIEMBROS'), findsOneWidget);
      expect(find.text('Agregar miembros'), findsOneWidget);
      expect(find.text('Elegir miembro'), findsNWidgets(3));
      expect(find.text('Opcional'), findsOneWidget);
      expect(h.notifier.created, isNull);
    });

    testWidgets('enviar vacío muestra los errores junto a cada campo',
        (tester) async {
      final h = await _open(tester);

      expect(find.text('Elige un secretario para la unidad'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('unit-form-save')));
      await _settle(tester);

      expect(find.text('Ingresa el nombre de la unidad.'), findsOneWidget);
      expect(find.text('Elige un capitán para la unidad'), findsOneWidget);
      expect(find.text('Elige un secretario para la unidad'), findsOneWidget);
      expect(find.text('Elige un consejero para la unidad'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(h.notifier.created, isNull);
      expect(find.byType(UnitFormView), findsOneWidget);
    });

    testWidgets('el error de un responsable desaparece al elegirlo',
        (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('unit-form-save')));
      await _settle(tester);
      expect(find.text('Elige un capitán para la unidad'), findsOneWidget);

      await _pickRole(tester, 'Capitán', 'Ana Castillo');

      expect(find.text('Elige un capitán para la unidad'), findsNothing);
      expect(find.text('Elige un secretario para la unidad'), findsOneWidget);
    });

    testWidgets('crea la unidad con responsables y miembros', (tester) async {
      final h = await _open(tester);

      await tester.enterText(find.byType(TextFormField), '  Halcones ');
      await _pickRole(tester, 'Capitán', 'Ana Castillo');
      await _pickRole(tester, 'Secretario', 'Bruno Díaz');
      await _pickRole(tester, 'Consejero', 'Carla Méndez');
      await _addMembers(tester, ['Diego Paredes', 'Elena Ruiz']);

      await tester.tap(find.byKey(const ValueKey('unit-form-save')));
      await _settle(tester);

      expect(h.notifier.created, {
        'name': 'Halcones',
        'captainId': 'u1',
        'secretaryId': 'u2',
        'advisorId': 'u3',
        'substituteAdvisorId': null,
        'clubTypeId': 2,
        'clubSectionId': 2,
        'memberUserIds': ['u4', 'u5'],
      });
      expect(find.byType(UnitFormView), findsNothing);
      expect(h.result.value, isTrue);
    });

    testWidgets('el consejero suplente es opcional y se puede quitar',
        (tester) async {
      final h = await _open(tester);
      await tester.enterText(find.byType(TextFormField), 'Águilas');
      await _pickRole(tester, 'Capitán', 'Ana Castillo');
      await _pickRole(tester, 'Secretario', 'Bruno Díaz');
      await _pickRole(tester, 'Consejero', 'Carla Méndez');
      await _pickRole(tester, 'Consejero suplente', 'Diego Paredes');
      expect(find.text('Opcional'), findsNothing);

      await tester.tap(find.byTooltip('Limpiar'));
      await _settle(tester);
      expect(find.text('Opcional'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('unit-form-save')));
      await _settle(tester);
      expect(h.notifier.created?['substituteAdvisorId'], isNull);
    });

    testWidgets('Cancelar cierra sin guardar', (tester) async {
      final h = await _open(tester);
      await tester.tap(find.byKey(const ValueKey('unit-form-cancel')));
      await _settle(tester);

      expect(find.byType(UnitFormView), findsNothing);
      expect(h.notifier.created, isNull);
      expect(h.result.value, isNull);
    });
  });

  group('pickers', () {
    testWidgets('no ofrece a quien ya tiene otro responsable', (tester) async {
      await _open(tester);
      await _pickRole(tester, 'Capitán', 'Ana Castillo');
      await _pickRole(tester, 'Secretario', 'Bruno Díaz');

      await tester.tap(find.widgetWithText(UnitFormRoleRow, 'Consejero'));
      await _settle(tester);

      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.text('Ana Castillo')),
          findsNothing);
      expect(find.descendant(of: sheet, matching: find.text('Bruno Díaz')),
          findsNothing);
      expect(find.descendant(of: sheet, matching: find.text('Carla Méndez')),
          findsOneWidget);
    });

    testWidgets('el selector de miembros oculta a los responsables',
        (tester) async {
      await _open(tester);
      await _pickRole(tester, 'Capitán', 'Ana Castillo');

      await tester.tap(find.text('Agregar miembros'));
      await _settle(tester);

      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.text('Ana Castillo')),
          findsNothing);
      expect(find.descendant(of: sheet, matching: find.text('Bruno Díaz')),
          findsOneWidget);
    });

    testWidgets('elegir como responsable a un miembro lo saca de miembros',
        (tester) async {
      final h = await _open(tester);
      await _addMembers(tester, ['Diego Paredes', 'Elena Ruiz']);
      await _pickRole(tester, 'Capitán', 'Diego Paredes');
      await _pickRole(tester, 'Secretario', 'Bruno Díaz');
      await _pickRole(tester, 'Consejero', 'Carla Méndez');
      await tester.enterText(find.byType(TextFormField), 'Leones');

      await tester.tap(find.byKey(const ValueKey('unit-form-save')));
      await _settle(tester);

      expect(h.notifier.created?['captainId'], 'u4');
      expect(h.notifier.created?['memberUserIds'], ['u5']);
    });
  });

  group('editar', () {
    testWidgets('precarga nombre, responsables y miembros', (tester) async {
      await _open(tester, unit: _editUnit);

      expect(find.text('Editar unidad'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Halcones'), findsOneWidget);
      expect(
          find.descendant(
              of: find.widgetWithText(UnitFormRoleRow, 'Capitán'),
              matching: find.text('Ana Castillo')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.widgetWithText(UnitFormRoleRow, 'Secretario'),
              matching: find.text('Bruno Díaz')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.widgetWithText(UnitFormRoleRow, 'Consejero'),
              matching: find.text('Carla Méndez')),
          findsOneWidget);
      expect(find.text('Opcional'), findsOneWidget);
      // 5 miembros: se ven 4 y "Ver los 1 restantes".
      expect(find.byType(UnitFormMemberRow), findsNWidgets(4));
      expect(find.text('Ver los 1 restantes'), findsOneWidget);
    });

    testWidgets('Ver los N restantes expande la lista', (tester) async {
      await _open(tester, unit: _editUnit);
      expect(find.text('Hugo Vera'), findsNothing);

      await tester.tap(find.text('Ver los 1 restantes'));
      await _settle(tester);

      expect(find.byType(UnitFormMemberRow), findsNWidgets(5));
      expect(find.text('Hugo Vera'), findsOneWidget);
      expect(find.text('Ver los 1 restantes'), findsNothing);
    });

    testWidgets('quitar y agregar miembros llega al guardado', (tester) async {
      final h = await _open(tester, unit: _editUnit);

      await tester.tap(find.byTooltip('Quitar a Diego Paredes'));
      await _settle(tester);
      await _addMembers(tester, ['Irene Wong']);
      await tester.tap(find.byTooltip('Quitar a Elena Ruiz'));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('unit-form-save')));
      await _settle(tester);

      expect(h.notifier.updated?['unitId'], 7);
      expect(h.notifier.updated?['name'], 'Halcones');
      expect(h.notifier.updated?['captainId'], 'u1');
      expect(h.notifier.updated?['memberUserIds'], ['u6', 'u7', 'u8', 'u9']);
      expect(h.result.value, isTrue);
    });

    testWidgets('el selector de un responsable excluye a los otros',
        (tester) async {
      await _open(tester, unit: _editUnit);

      await tester
          .tap(find.widgetWithText(UnitFormRoleRow, 'Consejero suplente'));
      await _settle(tester);

      final sheet = find.byType(BottomSheet);
      for (final taken in ['Ana Castillo', 'Bruno Díaz', 'Carla Méndez']) {
        expect(find.descendant(of: sheet, matching: find.text(taken)),
            findsNothing);
      }
      expect(find.descendant(of: sheet, matching: find.text('Diego Paredes')),
          findsOneWidget);
    });

    testWidgets('con el nombre vacío no guarda y muestra el error',
        (tester) async {
      final h = await _open(tester, unit: _editUnit);
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.byKey(const ValueKey('unit-form-save')));
      await _settle(tester);

      expect(find.text('Ingresa el nombre de la unidad.'), findsOneWidget);
      expect(h.notifier.updated, isNull);
    });
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _Harness {
  _Harness(this.notifier, this.result);

  final _RecordingUnitsNotifier notifier;
  final ValueNotifier<bool?> result;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_Harness> _open(WidgetTester tester, {Unit? unit}) async {
  tester.view.physicalSize = const Size(390, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final notifier = _RecordingUnitsNotifier();
  final result = ValueNotifier<bool?>(null);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        clubContextProvider.overrideWith(
          (ref) async => const ClubContext(
            clubId: 1,
            sectionId: 2,
            clubTypeName: 'Conquistadores',
          ),
        ),
        unitsNotifierProvider.overrideWith(() => notifier),
        getClubMembersUseCaseProvider
            .overrideWithValue(_FakeGetClubMembers(_people)),
        getUnitDetailUseCaseProvider
            .overrideWithValue(_FakeGetUnitDetail(_editDetail())),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const _FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      result.value = await openUnitForm(context, unit: unit),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.tap(find.text('Abrir'));
  await _settle(tester);
  return _Harness(notifier, result);
}

Future<void> _pickRole(WidgetTester tester, String role, String person) async {
  await tester.tap(find.widgetWithText(UnitFormRoleRow, role));
  await _settle(tester);
  await tester.tap(find.widgetWithText(ListTile, person));
  await _settle(tester);
}

/// Opens the multi-select picker and toggles [people], then confirms.
Future<void> _addMembers(WidgetTester tester, List<String> people) async {
  await tester.tap(find.text('Agregar miembros'));
  await _settle(tester);
  for (final p in people) {
    await tester.tap(find.widgetWithText(CheckboxListTile, p));
    await tester.pump();
  }
  await tester.tap(find.text('Listo'));
  await _settle(tester);
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
