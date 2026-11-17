import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/units/domain/entities/unit.dart';
import 'package:sacdia_app/features/units/presentation/providers/units_providers.dart';
import 'package:sacdia_app/features/units/presentation/views/unit_detail_view.dart';
import 'package:sacdia_app/features/units/presentation/views/units_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/riverpod_test_support.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

class _StaticUnitsNotifier extends UnitsNotifier {
  _StaticUnitsNotifier(this.initial);

  final UnitsState initial;

  int selectCalls = 0;

  @override
  UnitsState build() => initial;

  @override
  Future<void> selectUnit(Unit unit) async {
    selectCalls++;
    state = state.copyWith(selectedUnit: unit, members: unit.scoringMembers);
  }
}

final _manageMenus = find.byWidgetPredicate(
  (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedMoreHorizontal,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('muestra carga y no el vacío mientras llegan las unidades',
      (tester) async {
    await _pumpUnits(
      tester,
      units: const UnitsState(units: [], isLoading: true),
    );

    expect(find.byType(SacSkeletonList), findsOneWidget);
    expect(find.text('Cargando…'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No hay unidades'), findsNothing);
  });

  testWidgets('muestra el vacío cuando no hay unidades', (tester) async {
    await _pumpUnits(
      tester,
      units: const UnitsState(units: []),
    );

    expect(find.text('No hay unidades'), findsOneWidget);
    expect(
      find.text(
          'Contacta al director de tu club\npara que te asigne una unidad.'),
      findsOneWidget,
    );
    expect(find.text('Cargando…'), findsNothing);
    expect(find.byType(SacLoading), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('muestra las unidades cuando ya cargaron', (tester) async {
    await _pumpUnits(
      tester,
      units: UnitsState(units: [_unit('Águilas'), _unit('Leones', id: 2)]),
    );

    expect(find.text('Águilas'), findsOneWidget);
    expect(find.text('Leones'), findsOneWidget);
    expect(find.text('No hay unidades'), findsNothing);
    expect(find.text('Cargando…'), findsNothing);
    expect(find.byType(SacLoading), findsNothing);
    expect(
        find.text('Revisa quiénes recibieron el reconocimiento en la sección.'),
        findsNothing);
    expect(
      tester.widget<Text>(find.text('ÁG')).style?.color,
      AppColors.loginBrandBlue,
    );
  });

  testWidgets(
      'la directiva ve el historial de miembro del mes sin ganador actual',
      (tester) async {
    await _pumpUnits(
      tester,
      units: UnitsState(units: [_unit('Halcones'), _unit('Leones', id: 2)]),
      user: _member(permissions: const ['mom:read']),
    );

    expect(
      find.text('Revisa quiénes recibieron el reconocimiento en la sección.'),
      findsOneWidget,
    );
    expect(find.text('Halcones'), findsOneWidget);
  });

  group('lider de unidad sin units:update', () {
    UserEntity leader({List<String> permissions = const ['units:read']}) =>
        _member(permissions: permissions);

    testWidgets('ve solo sus unidades, sin crear ni gestionar', (tester) async {
      await _pumpUnits(
        tester,
        user: leader(),
        units: UnitsState(
          units: [
            _unit('Centinelas', id: 1, captainId: 'user-1'),
            _unit('Exploradores', id: 2, secretaryId: 'user-1'),
            _unit('Ajenos', id: 3, captainId: 'otro'),
          ],
        ),
      );

      expect(find.text('Centinelas'), findsOneWidget);
      expect(find.text('Exploradores'), findsOneWidget);
      expect(find.text('Ajenos'), findsNothing);
      // Sin boton "+" (crear unidad) en la barra.
      expect(find.byTooltip('Crear unidad'), findsNothing);
      // Sin menu "Gestionar unidad" (los tres puntos de cada tarjeta).
      expect(_manageMenus, findsNothing);
    });

    testWidgets('la directiva con units:update/create sigue gestionando',
        (tester) async {
      await _pumpUnits(
        tester,
        user: leader(
          permissions: const ['units:read', 'units:update', 'units:create'],
        ),
        units: UnitsState(
          units: [
            _unit('Centinelas', id: 1, captainId: 'otro'),
            _unit('Ajenos', id: 3, captainId: 'otro'),
          ],
        ),
      );

      expect(find.text('Centinelas'), findsOneWidget);
      expect(find.text('Ajenos'), findsOneWidget);
      expect(find.byTooltip('Crear unidad'), findsOneWidget);
      expect(_manageMenus, findsNWidgets(2));
    });
  });

  group('una sola unidad visible', () {
    const manager = ['units:read', 'units:update', 'units:create'];

    testWidgets('quien gestiona aterriza en la lista, sin esqueleto',
        (tester) async {
      final notifier =
          _StaticUnitsNotifier(UnitsState(units: [_unit('Halcones')]));
      await _pumpUnits(
        tester,
        user: _member(permissions: manager),
        notifier: notifier,
        units: UnitsState(units: [_unit('Halcones')]),
      );

      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.byType(UnitDetailView), findsNothing);
      expect(find.text('Halcones'), findsOneWidget);
      expect(find.byTooltip('Crear unidad'), findsOneWidget);
      expect(_manageMenus, findsOneWidget);
      expect(notifier.selectCalls, 0);
    });

    testWidgets('units:update solo tambien gestiona: nunca se redirige',
        (tester) async {
      final units = UnitsState(units: [_unit('Halcones')]);
      final notifier = _StaticUnitsNotifier(units);
      await _pumpUnits(
        tester,
        user: _member(permissions: const ['units:read', 'units:update']),
        notifier: notifier,
        units: units,
      );

      expect(find.byType(UnitDetailView), findsNothing);
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Halcones'), findsOneWidget);
      expect(notifier.selectCalls, 0);
    });

    testWidgets('quien no gestiona entra directo a su unica unidad una vez',
        (tester) async {
      final units = UnitsState(units: [_unit('Halcones')]);
      final notifier = _StaticUnitsNotifier(units);
      await _pumpUnits(
        tester,
        user: _member(permissions: const ['units:read']),
        notifier: notifier,
        units: units,
        viaHome: true,
      );

      expect(find.byType(UnitDetailView), findsOneWidget);
      expect(find.byType(UnitsListView), findsNothing);
      expect(notifier.selectCalls, 1);
    });

    testWidgets('al volver de la unidad no queda un esqueleto eterno',
        (tester) async {
      final units = UnitsState(units: [_unit('Halcones')]);
      final notifier = _StaticUnitsNotifier(units);
      await _pumpUnits(
        tester,
        user: _member(permissions: const ['units:read']),
        notifier: notifier,
        units: units,
        viaHome: true,
      );
      expect(find.byType(UnitDetailView), findsOneWidget);

      Navigator.of(tester.element(find.byType(UnitDetailView))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.byType(UnitDetailView), findsNothing);
      expect(notifier.selectCalls, 1);
    });

    testWidgets('quien gestiona abre la unidad, vuelve y ve la fila',
        (tester) async {
      final units = UnitsState(units: [_unit('Halcones')]);
      final notifier = _StaticUnitsNotifier(units);
      await _pumpUnits(
        tester,
        user: _member(permissions: manager),
        notifier: notifier,
        units: units,
      );

      await tester.tap(find.text('Halcones'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(UnitDetailView), findsOneWidget);

      Navigator.of(tester.element(find.byType(UnitDetailView))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(UnitDetailView), findsNothing);
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Halcones'), findsOneWidget);
      expect(find.byTooltip('Crear unidad'), findsOneWidget);
    });
  });
}

Unit _unit(
  String name, {
  int id = 1,
  String? captainId,
  String? secretaryId,
  String? advisorId,
}) {
  final noLeaderGiven =
      captainId == null && secretaryId == null && advisorId == null;
  return Unit(
    id: id,
    name: name,
    type: 'Conquistadores',
    memberCount: 4,
    clubSectionId: 2,
    captainId: captainId,
    secretaryId: secretaryId,
    advisorId: noLeaderGiven ? 'user-1' : advisorId,
  );
}

UserEntity _member({List<String> permissions = const []}) {
  return UserEntity(
    id: 'user-1',
    email: 'user@example.com',
    authorization: AuthorizationSnapshot(
      effectivePermissions: permissions,
      activeAssignmentId: 'assignment-1',
      clubAssignments: const [
        AuthorizationGrant(
          assignmentId: 'assignment-1',
          clubId: 1,
          sectionId: 2,
          status: 'active',
          roleName: 'counselor',
        ),
      ],
    ),
  );
}

Future<void> _pumpUnits(
  WidgetTester tester, {
  required UnitsState units,
  UserEntity? user,
  _StaticUnitsNotifier? notifier,
  bool viaHome = false,
}) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider
            .overrideWith(() => _FakeAuthNotifier(user ?? _member())),
        unitsNotifierProvider
            .overrideWith(() => notifier ?? _StaticUnitsNotifier(units)),
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
            home: viaHome ? const _Home() : const UnitsListView(),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  if (viaHome) {
    await tester.tap(find.text('Abrir unidades'));
  }
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  // La apertura automática de una sola unidad espera dos frames más.
  await tester.pump(const Duration(milliseconds: 600));
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inicio'),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const UnitsListView()),
              ),
              child: const Text('Abrir unidades'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
