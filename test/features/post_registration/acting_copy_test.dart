import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
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
import 'package:sacdia_app/features/post_registration/presentation/views/personal_info_step_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/widgets/profile_photo_picker.dart';

import '../family/family_test_harness.dart';

class _EmptyClubDataSource implements ClubSelectionRemoteDataSource {
  @override
  Future<List<CountryModel>> getCountries({CancelToken? cancelToken}) async =>
      const [];
  @override
  Future<List<UnionModel>> getUnionsByCountry(int countryId,
          {CancelToken? cancelToken}) async =>
      const [];
  @override
  Future<List<LocalFieldModel>> getLocalFieldsByUnion(int unionId,
          {CancelToken? cancelToken}) async =>
      const [];
  @override
  Future<List<ClubModel>> getClubsByLocalField(int localFieldId,
          {CancelToken? cancelToken}) async =>
      const [];
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

ActingForSession _actingAs(String? firstName) => ActingForSession()
  ..enter(ActingDependent(userId: 'ana-1', firstName: firstName));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget child, {
    ActingForSession? session,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => FakeAuthNotifier(guardianUser)),
        clubSelectionDataSourceProvider
            .overrideWithValue(_EmptyClubDataSource()),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('step 3 (club selection)', () {
    testWidgets('keeps the second-person copy when not acting', (tester) async {
      await pumpScreen(tester, const ClubSelectionStepView());

      expect(find.text('Encuentra tu club'), findsOneWidget);
      expect(
        find.text('Selecciona tu ubicación y club para unirte a la aventura'),
        findsOneWidget,
      );
      expect(find.textContaining('Ana'), findsNothing);
    });

    testWidgets('uses the minor name in third person while acting',
        (tester) async {
      await pumpScreen(tester, const ClubSelectionStepView(),
          session: _actingAs('Ana'));

      expect(find.text('Elige el club de Ana'), findsOneWidget);
      expect(
        find.text(
            'Selecciona la ubicación y el club para que Ana se una a la aventura'),
        findsOneWidget,
      );
      expect(find.text('Encuentra tu club'), findsNothing);
    });

    testWidgets('a club transfer keeps its own copy even if acting',
        (tester) async {
      await pumpScreen(
          tester, const ClubSelectionStepView(isClubTransfer: true),
          session: _actingAs('Ana'));

      expect(find.text('Elige el club de Ana'), findsNothing);
      expect(find.text('Encuentra tu club'), findsNothing);
    });

    testWidgets('without a first name it never falls back to "tu"',
        (tester) async {
      await pumpScreen(tester, const ClubSelectionStepView(),
          session: _actingAs('  '));

      expect(find.text('Elige el club de este menor'), findsOneWidget);
      expect(find.text('Encuentra tu club'), findsNothing);
    });
  });

  group('step 1 (photo)', () {
    ProfilePhotoPicker picker({String? actingName}) => ProfilePhotoPicker(
          onTakePhoto: () {},
          onPickFromGallery: () {},
          actingName: actingName,
        );

    testWidgets('second person when not acting', (tester) async {
      await pumpScreen(tester, picker());

      expect(find.text('¡Ponle cara a tu aventura!'), findsOneWidget);
      expect(find.text('Sube una foto de Ana'), findsNothing);
    });

    testWidgets('third person with the name while acting', (tester) async {
      await pumpScreen(tester, picker(actingName: 'Ana'));

      expect(find.text('Sube una foto de Ana'), findsOneWidget);
      expect(find.text('Así reconocerán a Ana en su club'), findsOneWidget);
      expect(find.text('¡Ponle cara a tu aventura!'), findsNothing);
    });
  });

  group('step 2 (personal info)', () {
    Widget view() => const SizedBox(
          height: 2500,
          child: PersonalInfoStepView(
            canReadSensitiveData: true,
            canManageAdministrativeCompletion: true,
            targetUserId: 'ana-1',
          ),
        );

    testWidgets('second person when not acting', (tester) async {
      await pumpScreen(tester, view());

      expect(find.text('Cuéntanos sobre ti'), findsOneWidget);
      expect(find.text('¿Estás bautizado?'), findsOneWidget);
    });

    testWidgets('third person with the name while acting', (tester) async {
      await pumpScreen(tester, view(), session: _actingAs('Ana'));

      expect(find.text('Cuéntanos sobre Ana'), findsOneWidget);
      expect(find.text('¿Está bautizado(a) Ana?'), findsOneWidget);
      expect(find.text('Cuéntanos sobre ti'), findsNothing);
      expect(find.text('¿Estás bautizado?'), findsNothing);
    });
  });

  test('every acting variant exists in the 4 locales and takes the name', () {
    const keys = {
      'photo': ['title_acting', 'subtitle_acting'],
      'personal_info': ['title_acting', 'subtitle_acting'],
      'club_selection': ['title_acting', 'subtitle_acting'],
    };
    for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final pr = json['post_registration'] as Map<String, dynamic>;
      final texts = <String>[
        for (final entry in keys.entries)
          for (final key in entry.value)
            (pr[entry.key] as Map<String, dynamic>)[key] as String,
        ((pr['personal_info'] as Map<String, dynamic>)['baptism']
            as Map<String, dynamic>)['toggle_label_acting'] as String,
      ];
      for (final text in texts) {
        expect(text, contains('{name}'), reason: '$locale: $text');
      }
      expect(
        (pr['acting'] as Map<String, dynamic>)['name_fallback'],
        isNotEmpty,
        reason: locale,
      );
    }
  });
}
