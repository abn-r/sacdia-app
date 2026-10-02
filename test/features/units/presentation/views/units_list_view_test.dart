import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/units/domain/entities/unit.dart';
import 'package:sacdia_app/features/units/presentation/providers/units_providers.dart';
import 'package:sacdia_app/features/units/presentation/views/units_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

class _StaticUnitsNotifier extends UnitsNotifier {
  _StaticUnitsNotifier(this.initial);

  final UnitsState initial;

  @override
  UnitsState build() => initial;
}

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

    expect(find.byType(SacLoading), findsOneWidget);
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
}

Unit _unit(String name, {int id = 1}) {
  return Unit(
    id: id,
    name: name,
    type: 'Conquistadores',
    memberCount: 4,
    clubSectionId: 2,
    advisorId: 'user-1',
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider
            .overrideWith(() => _FakeAuthNotifier(user ?? _member())),
        unitsNotifierProvider.overrideWith(() => _StaticUnitsNotifier(units)),
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
            home: const UnitsListView(),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}
