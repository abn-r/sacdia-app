import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/units/domain/entities/scoring_category.dart';
import 'package:sacdia_app/features/units/domain/entities/unit.dart';
import 'package:sacdia_app/features/units/domain/entities/unit_member.dart';
import 'package:sacdia_app/features/units/domain/unit_access.dart';
import 'package:sacdia_app/features/units/presentation/providers/units_providers.dart';
import 'package:sacdia_app/features/units/presentation/views/unit_detail_view.dart';
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

const _saveLabel = 'Guardar semana';
const _bulkLabel = 'A todos';
const _historyLabel = 'Puntos de semanas anteriores';

UserEntity _user(List<String> permissions, {String id = 'user-1'}) {
  return UserEntity(
    id: id,
    email: 'user@example.com',
    authorization: AuthorizationSnapshot(effectivePermissions: permissions),
  );
}

Unit _unit({
  String? captainId,
  String? secretaryId,
  String? advisorId,
  String? substituteAdvisorId,
}) {
  return Unit(
    id: 7,
    name: 'Centinelas',
    type: 'Guias Mayores',
    memberCount: 1,
    clubSectionId: 2,
    captainId: captainId,
    secretaryId: secretaryId,
    advisorId: advisorId,
    substituteAdvisorId: substituteAdvisorId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('canRegisterUnitPoints', () {
    test('director (units:update + units:create) captures any unit', () {
      final director =
          _user(const ['units:read', 'units:update', 'units:create']);
      expect(canRegisterUnitPoints(director, _unit(captainId: 'x')), isTrue);
    });

    test('a member leading the unit captures it without units:update', () {
      final member = _user(const ['units:read']);
      expect(canRegisterUnitPoints(member, _unit(captainId: 'user-1')), isTrue);
      expect(
          canRegisterUnitPoints(member, _unit(secretaryId: 'user-1')), isTrue);
      expect(canRegisterUnitPoints(member, _unit(advisorId: 'user-1')), isTrue);
      expect(
        canRegisterUnitPoints(member, _unit(substituteAdvisorId: 'user-1')),
        isTrue,
      );
    });

    test('units:read without leading the unit stays read-only', () {
      final member = _user(const ['units:read']);
      expect(canRegisterUnitPoints(member, _unit(captainId: 'other')), isFalse);
      expect(canRegisterUnitPoints(member, _unit()), isFalse);
    });

    test('units:update without create only captures units they lead', () {
      final counselor = _user(const ['units:read', 'units:update']);
      expect(canRegisterUnitPoints(counselor, _unit(captainId: 'x')), isFalse);
      expect(
          canRegisterUnitPoints(counselor, _unit(advisorId: 'user-1')), isTrue);
    });

    test('no user never captures', () {
      expect(canRegisterUnitPoints(null, _unit(captainId: 'user-1')), isFalse);
    });
  });

  group('UnitDetailView points sheet', () {
    testWidgets('a leader of the unit can capture and save the sheet',
        (tester) async {
      await _pumpDetail(
        tester,
        user: _user(const ['units:read']),
        unit: _unit(captainId: 'user-1'),
      );

      expect(find.text(_saveLabel), findsOneWidget);
      expect(find.text(_bulkLabel), findsOneWidget);
      expect(find.text(_historyLabel), findsOneWidget);
    });

    testWidgets('a reader who does not lead the unit stays read-only',
        (tester) async {
      await _pumpDetail(
        tester,
        user: _user(const ['units:read']),
        unit: _unit(captainId: 'other'),
      );

      expect(find.text(_saveLabel), findsNothing);
      expect(find.text(_bulkLabel), findsNothing);
      // The history is still reachable.
      expect(find.text(_historyLabel), findsOneWidget);
    });

    testWidgets('a director keeps editing any unit', (tester) async {
      await _pumpDetail(
        tester,
        user: _user(const ['units:read', 'units:update', 'units:create']),
        unit: _unit(captainId: 'other'),
      );

      expect(find.text(_saveLabel), findsOneWidget);
      expect(find.text(_bulkLabel), findsOneWidget);
    });
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required UserEntity user,
  required Unit unit,
}) async {
  final state = UnitsState(
    units: [unit],
    selectedUnit: unit,
    members: const [
      UnitMember(id: 'm-1', name: 'Ana', surname: 'Lopez'),
    ],
    categories: const [
      ScoringCategory(
        scoringCategoryId: 1,
        name: 'Asistencia',
        maxPoints: 10,
        originLevel: 'LOCAL_FIELD',
        originId: 1,
      ),
    ],
    pendingScores: const {
      'm-1': {1: 0},
    },
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        unitsNotifierProvider.overrideWith(() => _StaticUnitsNotifier(state)),
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
            home: UnitDetailView(unit: unit),
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
