import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/data/datasources/catalogs_remote_data_source.dart';
import 'package:sacdia_app/shared/models/catalogs/catalogs.dart';

class _FakeCatalogsRemoteDataSource implements CatalogsRemoteDataSource {
  _FakeCatalogsRemoteDataSource({
    List<ClubTypeModel>? clubTypes,
    List<ActivityTypeModel>? activityTypes,
    List<DistrictModel>? districts,
    List<ChurchModel>? churches,
    List<EcclesiasticalYearModel>? ecclesiasticalYears,
    EcclesiasticalYearModel? currentEcclesiasticalYear,
  })  : _clubTypes = clubTypes ?? const [],
        _activityTypes = activityTypes ?? const [],
        _districts = districts ?? const [],
        _churches = churches ?? const [],
        _ecclesiasticalYears = ecclesiasticalYears ?? const [],
        _currentEcclesiasticalYear = currentEcclesiasticalYear;

  final List<ClubTypeModel> _clubTypes;
  final List<ActivityTypeModel> _activityTypes;
  final List<DistrictModel> _districts;
  final List<ChurchModel> _churches;
  final List<EcclesiasticalYearModel> _ecclesiasticalYears;
  final EcclesiasticalYearModel? _currentEcclesiasticalYear;

  int clubTypesCalls = 0;
  int activityTypesCalls = 0;
  int districtsCalls = 0;
  int churchesCalls = 0;
  int ecclesiasticalYearsCalls = 0;
  int currentEcclesiasticalYearCalls = 0;

  @override
  Future<List<ClubTypeModel>> getClubTypes({CancelToken? cancelToken}) async {
    clubTypesCalls++;
    return _clubTypes;
  }

  @override
  Future<List<ActivityTypeModel>> getActivityTypes({
    CancelToken? cancelToken,
  }) async {
    activityTypesCalls++;
    return _activityTypes;
  }

  @override
  Future<List<DistrictModel>> getDistricts({
    int? localFieldId,
    CancelToken? cancelToken,
  }) async {
    districtsCalls++;
    return _districts;
  }

  @override
  Future<List<ChurchModel>> getChurches({
    int? districtId,
    CancelToken? cancelToken,
  }) async {
    churchesCalls++;
    return _churches;
  }

  @override
  Future<List<EcclesiasticalYearModel>> getEcclesiasticalYears({
    bool? active,
    CancelToken? cancelToken,
  }) async {
    ecclesiasticalYearsCalls++;
    return _ecclesiasticalYears;
  }

  @override
  Future<EcclesiasticalYearModel?> getCurrentEcclesiasticalYear({
    CancelToken? cancelToken,
  }) async {
    currentEcclesiasticalYearCalls++;
    return _currentEcclesiasticalYear;
  }
}

Future<ProviderContainer> _buildCatalogsContainer({
  required CatalogsRemoteDataSource dataSource,
  required Map<String, Object> initialPrefs,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      catalogsDataSourceProvider.overrideWithValue(dataSource),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

ClubTypeModel _sampleClubType() => const ClubTypeModel(
      clubTypeId: 1,
      name: 'Guías',
      description: 'A',
    );

EcclesiasticalYearModel _sampleEcclesiasticalYear() => EcclesiasticalYearModel(
      ecclesiasticalYearId: 2026,
      name: '2026-2027',
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 12, 31),
      active: true,
    );

void main() {
  group('Catalogs provider TTL cache', () {
    test('uses local cached club types when cache is within TTL', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final catalog = _sampleClubType();
      final dataSource = _FakeCatalogsRemoteDataSource(clubTypes: [catalog]);
      final container = await _buildCatalogsContainer(
        dataSource: dataSource,
        initialPrefs: {
          AppConstants.catalogClubTypesCacheKey: jsonEncode([catalog.toJson()]),
          '${AppConstants.catalogClubTypesCacheKey}_cached_at': now,
          'unrelated_pref': 'keep',
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(clubTypesProvider.future);

      expect(result, isA<List<ClubTypeModel>>());
      expect(result.first.clubTypeId, catalog.clubTypeId);
      expect(dataSource.clubTypesCalls, equals(0));
    });

    test('falls back to remote catalog call when TTL has expired', () async {
      final now = DateTime.now()
          .subtract(const Duration(hours: 24, seconds: 2))
          .millisecondsSinceEpoch;
      final cached = _sampleClubType();
      final remote = const ClubTypeModel(
        clubTypeId: 2,
        name: 'Conquistadores',
      );
      final dataSource = _FakeCatalogsRemoteDataSource(clubTypes: [remote]);
      final container = await _buildCatalogsContainer(
        dataSource: dataSource,
        initialPrefs: {
          AppConstants.catalogClubTypesCacheKey: jsonEncode([cached.toJson()]),
          '${AppConstants.catalogClubTypesCacheKey}_cached_at': now,
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(clubTypesProvider.future);

      expect(result.first.clubTypeId, remote.clubTypeId);
      expect(dataSource.clubTypesCalls, equals(1));
    });

    test('falls back to remote catalog when cached payload cannot be decoded',
        () async {
      final remote = const ClubTypeModel(
        clubTypeId: 3,
        name: 'Conquistas',
      );
      final dataSource = _FakeCatalogsRemoteDataSource(clubTypes: [remote]);
      final container = await _buildCatalogsContainer(
        dataSource: dataSource,
        initialPrefs: {
          AppConstants.catalogClubTypesCacheKey: 'not-a-json',
          '${AppConstants.catalogClubTypesCacheKey}_cached_at':
              DateTime.now().millisecondsSinceEpoch,
        },
      );
      addTearDown(container.dispose);

      final result = await container.read(clubTypesProvider.future);

      expect(result.first.clubTypeId, remote.clubTypeId);
      expect(dataSource.clubTypesCalls, equals(1));
    });

    test('reads current ecclesiastical year from cache when valid', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final year = _sampleEcclesiasticalYear();
      final dataSource = _FakeCatalogsRemoteDataSource(
        currentEcclesiasticalYear: year,
      );
      final container = await _buildCatalogsContainer(
        dataSource: dataSource,
        initialPrefs: {
          AppConstants.catalogCurrentEcclesiasticalYearCacheKey:
              jsonEncode([year.toJson()]),
          '${AppConstants.catalogCurrentEcclesiasticalYearCacheKey}_cached_at':
              now,
        },
      );
      addTearDown(container.dispose);

      final result =
          await container.read(currentEcclesiasticalYearProvider.future);

      expect(result, isNotNull);
      expect(result!.ecclesiasticalYearId, year.ecclesiasticalYearId);
      expect(dataSource.currentEcclesiasticalYearCalls, equals(0));
    });
  });
}
