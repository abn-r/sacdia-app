import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/data/models/class_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_section_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/country_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/local_field_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/union_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_flow_providers.dart';

import '../family/family_test_harness.dart';
import '../../support/riverpod_test_support.dart';

class _Step3DataSource implements ClubSelectionRemoteDataSource {
  _Step3DataSource(this.step3Error);

  final AppException? step3Error;

  @override
  Future<void> completeStep3({
    required String userId,
    required int countryId,
    required int unionId,
    required int localFieldId,
    required int clubSectionId,
    int? classId,
  }) async {
    if (step3Error != null) throw step3Error!;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  Future<PostRegistrationFlowResult> runStep3(AppException? error) async {
    final container = createTestContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => FakeAuthNotifier()),
        clubSelectionDataSourceProvider
            .overrideWithValue(_Step3DataSource(error)),
        selectedCountryProvider.overrideWith((ref) => 25),
        selectedUnionProvider.overrideWith((ref) => 20),
        selectedLocalFieldProvider.overrideWith((ref) => 4),
        selectedClubSectionProvider.overrideWith((ref) => 163),
      ],
    );
    await container.read(authNotifierProvider.future);
    final sub = container.listen(
      postRegistrationFlowNotifierProvider,
      (_, __) {},
    );
    addTearDown(sub.close);
    return container
        .read(postRegistrationFlowNotifierProvider.notifier)
        .completeStep3();
  }

  test('a 409 duplicate membership is a failure, never a silent success',
      () async {
    final result = await runStep3(ServerException(
      message: 'x',
      code: 409,
      errorCode: 'POST_REG_DUPLICATE_MEMBERSHIP',
    ));

    expect(result.success, isFalse);
    expect(result.errorCode, 'POST_REG_DUPLICATE_MEMBERSHIP');
  });

  test('a 409 class already enrolled is a failure too', () async {
    final result = await runStep3(ServerException(
      message: 'x',
      code: 409,
      errorCode: 'CLASS_ALREADY_ENROLLED',
    ));

    expect(result.success, isFalse);
    expect(result.errorCode, 'CLASS_ALREADY_ENROLLED');
  });

  test('success still succeeds', () async {
    final result = await runStep3(null);

    expect(result.success, isTrue);
  });
}
