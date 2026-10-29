import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/data/models/class_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_section_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/country_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/local_field_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/union_model.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/post_registration_shell.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../family/family_test_harness.dart';

class _Step3DataSource implements ClubSelectionRemoteDataSource {
  int step3Calls = 0;

  @override
  Future<void> completeStep3({
    required String userId,
    required int countryId,
    required int unionId,
    required int localFieldId,
    required int clubSectionId,
    int? classId,
  }) async {
    step3Calls++;
  }

  @override
  Future<void> completeGuardianOnly({
    required String userId,
    int? countryId,
    int? unionId,
    int? localFieldId,
  }) async {}

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
}

class _Step3Status extends CompletionStatusNotifier {
  @override
  Future<CompletionStatus?> build() async => const CompletionStatus(
        isComplete: false,
        currentStep: 3,
        photoComplete: true,
        personalInfoComplete: true,
        clubSelectionComplete: false,
      );
}

/// El real registra el push (Firebase) al marcar el post-registro completo.
class _Auth extends FakeAuthNotifier {
  int completions = 0;

  @override
  void markPostRegisterComplete({String? forUserId}) => completions++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late _Step3DataSource dataSource;
  late ProviderContainer container;

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    dataSource = _Step3DataSource();
    final repo = FakeFamilyRepository();
    final prefs = await SharedPreferences.getInstance();
    await pumpFamilyApp(
      tester,
      overrides: [
        ...familyOverrides(repo: repo, auth: _Auth()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        completionStatusProvider.overrideWith(_Step3Status.new),
        clubSelectionDataSourceProvider.overrideWithValue(dataSource),
        selectedCountryProvider.overrideWith((ref) => 25),
        selectedUnionProvider.overrideWith((ref) => 20),
        selectedLocalFieldProvider.overrideWith((ref) => 4),
        selectedClubSectionProvider.overrideWith((ref) => 163),
        canCompleteStep3Provider.overrideWithValue(true),
      ],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const PostRegistrationShell()),
        stubRoute(RouteNames.homeDashboard),
      ],
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    container = ProviderScope.containerOf(
      tester.element(find.byType(PostRegistrationShell)),
    );
  }

  void setPhase(ConsentFormPhase phase) =>
      container.read(consentFormPhaseProvider.notifier).state = phase;

  testWidgets('with nothing pending, Finalizar completes step 3',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(dataSource.step3Calls, 1);
    expect(find.text('route:${RouteNames.homeDashboard}'), findsOneWidget);
  });

  testWidgets('while the form is uploading, Finalizar is blocked with a notice',
      (tester) async {
    await pumpShell(tester);
    setPhase(ConsentFormPhase.uploading);

    await tester.tap(find.text('Finalizar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(dataSource.step3Calls, 0);
    expect(
      find.text(
        'Se está subiendo la ficha firmada. Espera a que termine para finalizar.',
      ),
      findsOneWidget,
    );
    expect(find.text('route:${RouteNames.homeDashboard}'), findsNothing);
  });

  testWidgets('a picked-but-not-uploaded form asks first; going back blocks',
      (tester) async {
    await pumpShell(tester);
    setPhase(ConsentFormPhase.pendingFile);

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('La ficha firmada no se subió'), findsOneWidget);
    await tester.tap(find.text('Volver y reintentar'));
    await tester.pumpAndSettle();

    expect(dataSource.step3Calls, 0);
    expect(find.text('route:${RouteNames.homeDashboard}'), findsNothing);
  });

  testWidgets('a picked-but-not-uploaded form can be left out on purpose',
      (tester) async {
    await pumpShell(tester);
    setPhase(ConsentFormPhase.pendingFile);

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar sin subirla'));
    await tester.pumpAndSettle();

    expect(dataSource.step3Calls, 1);
    expect(find.text('route:${RouteNames.homeDashboard}'), findsOneWidget);
  });
}
