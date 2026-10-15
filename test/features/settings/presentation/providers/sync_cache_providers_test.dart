import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/realtime/realtime_ref.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_group.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/settings/domain/entities/cache_info.dart';
import 'package:sacdia_app/features/settings/domain/entities/sync_result.dart';
import 'package:sacdia_app/features/settings/domain/repositories/cache_repository.dart';
import 'package:sacdia_app/features/settings/presentation/providers/sync_cache_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:sacdia_app/shared/data/datasources/catalogs_remote_data_source.dart';
import 'package:sacdia_app/shared/models/catalogs/catalogs.dart';

class _FakeCacheRepository implements CacheRepository {
  int imageClears = 0;
  int dataClears = 0;

  @override
  Future<CacheInfo> getCacheInfo() async => CacheInfo.empty;

  @override
  Future<void> clearImageCaches() async {
    imageClears++;
  }

  @override
  Future<void> clearAllData() async {
    dataClears++;
  }

  @override
  Future<SyncResult> recordSuccessfulSync(DateTime syncedAt) async {
    return SyncResult.ok(syncedAt);
  }
}

class _IdleDashboard extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _FakeCatalogsRemoteDataSource implements CatalogsRemoteDataSource {
  _FakeCatalogsRemoteDataSource(this.clubTypes);

  final List<ClubTypeModel> clubTypes;
  int clubTypesCalls = 0;

  @override
  Future<List<ClubTypeModel>> getClubTypes({CancelToken? cancelToken}) async {
    clubTypesCalls++;
    return clubTypes;
  }

  @override
  Future<List<ActivityTypeModel>> getActivityTypes({
    CancelToken? cancelToken,
  }) async =>
      const [];

  @override
  Future<List<DistrictModel>> getDistricts({
    int? localFieldId,
    CancelToken? cancelToken,
  }) async =>
      const [];

  @override
  Future<List<ChurchModel>> getChurches({
    int? districtId,
    CancelToken? cancelToken,
  }) async =>
      const [];

  @override
  Future<List<EcclesiasticalYearModel>> getEcclesiasticalYears({
    bool? active,
    CancelToken? cancelToken,
  }) async =>
      const [];

  @override
  Future<EcclesiasticalYearModel?> getCurrentEcclesiasticalYear({
    CancelToken? cancelToken,
  }) async =>
      null;
}

final _syncRunnerProvider = Provider<Future<SyncResult> Function()>((ref) {
  return () =>
      ref.read(syncControllerProvider.notifier).run(RealtimeRef.fromRef(ref));
});

final _clearRunnerProvider = Provider<Future<bool> Function(ClearCacheMode)>(
  (ref) {
    return (mode) => ref.read(clearCacheControllerProvider.notifier).run(mode);
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('force sync refetches a catalog that is still inside the TTL', () async {
    final cached = const ClubTypeModel(clubTypeId: 1, name: 'Guías');
    final remote = const ClubTypeModel(clubTypeId: 2, name: 'Conquistadores');
    final dataSource = _FakeCatalogsRemoteDataSource([remote]);
    const dashboardKey = '${AppConstants.dashboardSummaryCacheKeyPrefix}_u_a';

    SharedPreferences.setMockInitialValues({
      AppConstants.catalogClubTypesCacheKey: jsonEncode([cached.toJson()]),
      '${AppConstants.catalogClubTypesCacheKey}_cached_at':
          DateTime.now().millisecondsSinceEpoch,
      dashboardKey: '{"user_name":"Ana"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeCacheRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cacheRepositoryProvider.overrideWithValue(repo),
        catalogsDataSourceProvider.overrideWithValue(dataSource),
        clubContextProvider.overrideWith((ref) async => null),
        dashboardNotifierProvider.overrideWith(_IdleDashboard.new),
        userClassesProvider.overrideWith((ref) async => <ProgressiveClass>[]),
        userHonorsProvider.overrideWith((ref) async => <UserHonor>[]),
        honorCategoriesProvider.overrideWith(
          (ref) async => <HonorCategory>[],
        ),
        honorsGroupedByCategoryProvider.overrideWith(
          (ref) async => <HonorGroup>[],
        ),
        allHonorsProvider.overrideWith((ref) async => <Honor>[]),
      ],
    );
    addTearDown(container.dispose);

    final before = await container.read(clubTypesProvider.future);
    expect(before.first.clubTypeId, cached.clubTypeId);
    expect(dataSource.clubTypesCalls, 0);

    final result = await container.read(_syncRunnerProvider)();

    expect(result.success, isTrue);
    expect(prefs.getString(dashboardKey), isNull);

    final after = await container.read(clubTypesProvider.future);
    expect(after.first.clubTypeId, remote.clubTypeId);
    expect(dataSource.clubTypesCalls, 1);
  });

  test('clear all data drops in-memory catalogs; images only does not',
      () async {
    var builds = 0;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeCacheRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cacheRepositoryProvider.overrideWithValue(repo),
        clubContextProvider.overrideWith((ref) async => null),
        clubTypesProvider.overrideWith((ref) async {
          builds++;
          return <ClubTypeModel>[];
        }),
        dashboardNotifierProvider.overrideWith(_IdleDashboard.new),
        userClassesProvider.overrideWith((ref) async => <ProgressiveClass>[]),
        userHonorsProvider.overrideWith((ref) async => <UserHonor>[]),
        honorCategoriesProvider.overrideWith(
          (ref) async => <HonorCategory>[],
        ),
        honorsGroupedByCategoryProvider.overrideWith(
          (ref) async => <HonorGroup>[],
        ),
        allHonorsProvider.overrideWith((ref) async => <Honor>[]),
      ],
    );
    addTearDown(container.dispose);

    await container.read(clubTypesProvider.future);
    expect(builds, 1);

    final imagesOk =
        await container.read(_clearRunnerProvider)(ClearCacheMode.imagesOnly);
    expect(imagesOk, isTrue);
    expect(repo.imageClears, 1);
    await container.read(clubTypesProvider.future);
    expect(builds, 1);

    final dataOk =
        await container.read(_clearRunnerProvider)(ClearCacheMode.allData);
    expect(dataOk, isTrue);
    expect(repo.dataClears, 1);
    await container.read(clubTypesProvider.future);
    expect(builds, 2);
  });
}
