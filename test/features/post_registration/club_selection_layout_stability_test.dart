import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/data/models/class_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_section_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/country_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/local_field_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/union_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/club_selection_step_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/widgets/bottom_sheet_picker.dart';

import '../family/family_test_harness.dart';

/// Geografía con una sola opción (se autoselecciona en cascada) y clubes que
/// responden cuando el test lo decide.
class _SlowClubs implements ClubSelectionRemoteDataSource {
  // Se crea dentro del test: un Completer de `setUp` vive fuera de la zona de
  // FakeAsync y sus microtareas no se vacían con `pump`.
  final clubs = Completer<List<ClubModel>>();

  @override
  Future<List<ClubModel>> getClubsByLocalField(int localFieldId,
          {CancelToken? cancelToken}) =>
      clubs.future;

  @override
  Future<List<CountryModel>> getCountries({CancelToken? cancelToken}) async =>
      const [CountryModel(id: 1, name: 'México')];

  @override
  Future<List<UnionModel>> getUnionsByCountry(int countryId,
          {CancelToken? cancelToken}) async =>
      const [UnionModel(id: 1, name: 'Unión Norte', countryId: 1)];

  @override
  Future<List<LocalFieldModel>> getLocalFieldsByUnion(int unionId,
          {CancelToken? cancelToken}) async =>
      const [LocalFieldModel(id: 1, name: 'Campo A', unionId: 1)];

  @override
  Future<List<ClubSectionModel>> getClubSections(int clubId,
          {CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<List<ClassModel>> getClassesByClubType(int clubTypeId,
          {CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<void> completeStep3({
    required String userId,
    required int countryId,
    required int unionId,
    required int localFieldId,
    required int clubSectionId,
    int? classId,
  }) async {}

  @override
  Future<void> completeGuardianOnly({
    required String userId,
    int? countryId,
    int? unionId,
    int? localFieldId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late _SlowClubs ds;

  Future<void> pumpStep(
    WidgetTester tester, {
    bool forceGeography = true,
  }) async {
    ds = _SlowClubs();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => FakeAuthNotifier(guardianUser)),
        clubSelectionDataSourceProvider.overrideWithValue(ds),
        if (forceGeography) ...[
          selectedCountryProvider.overrideWith((ref) => 1),
          selectedUnionProvider.overrideWith((ref) => 1),
          selectedLocalFieldProvider.overrideWith((ref) => 1),
        ],
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: ClubSelectionStepView()),
        ),
      ],
    );
    await tester.pump();
  }

  final exitFinder = find.text('Solo soy tutor de menores');

  testWidgets('every picker slot is on screen while the catalogs load',
      (tester) async {
    await pumpStep(tester, forceGeography: false);

    // Nothing is selected yet: the cascade slots still exist, disabled.
    for (final label in const [
      'País',
      'Unión',
      'Campo Local',
      'Club',
      'Tipo de Club',
      'Clase Progresiva',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the layout does not move when the clubs arrive', (tester) async {
    await pumpStep(tester);

    // Clubs still loading: the slot exists and shows the spinner state.
    expect(find.text('Club'), findsOneWidget);
    final clubTop = tester.getTopLeft(find.text('Club'));
    final exitTop = tester.getTopLeft(exitFinder);
    final clubTypeTop = tester.getTopLeft(find.text('Tipo de Club'));
    final classTop = tester.getTopLeft(find.text('Clase Progresiva'));

    ds.clubs.complete(const [
      ClubModel(id: 1, name: 'Club Alfa', localFieldId: 1),
      ClubModel(id: 2, name: 'Club Beta', localFieldId: 1),
    ]);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Club')), clubTop);
    expect(tester.getTopLeft(find.text('Tipo de Club')), clubTypeTop);
    expect(tester.getTopLeft(find.text('Clase Progresiva')), classTop);
    expect(tester.getTopLeft(exitFinder), exitTop);
  });

  testWidgets('a single tap on the enabled club field opens the sheet',
      (tester) async {
    await pumpStep(tester);
    ds.clubs.complete(const [
      ClubModel(id: 1, name: 'Club Alfa', localFieldId: 1),
      ClubModel(id: 2, name: 'Club Beta', localFieldId: 1),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seleccionar club'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheetPickerSheet), findsOneWidget);
    expect(find.text('Club Alfa'), findsOneWidget);
  });

  testWidgets('tapping the club slot while it loads does nothing',
      (tester) async {
    await pumpStep(tester);

    await tester.tap(find.text('Club'), warnIfMissed: false);
    await tester.pump();

    expect(find.byType(BottomSheetPickerSheet), findsNothing);

    // Once the data arrives the very next tap opens it.
    ds.clubs.complete(const [
      ClubModel(id: 1, name: 'Club Alfa', localFieldId: 1),
      ClubModel(id: 2, name: 'Club Beta', localFieldId: 1),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar club'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheetPickerSheet), findsOneWidget);
  });
}
