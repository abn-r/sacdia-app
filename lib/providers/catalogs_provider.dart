import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/storage/local_storage.dart';
import '../shared/data/datasources/catalogs_remote_data_source.dart';
import '../shared/models/catalogs/catalogs.dart';
import 'dio_provider.dart';
import '../providers/storage_provider.dart';

const Duration _catalogsTtl = Duration(hours: 24);

String _districtsCacheKey(int? localFieldId) =>
    '${AppConstants.catalogDistrictsCacheKey}'
    '${localFieldId == null ? '' : '_local_field_$localFieldId'}';

String _churchesCacheKey(int? districtId) =>
    '${AppConstants.catalogChurchesCacheKey}'
    '${districtId == null ? '' : '_district_$districtId'}';

String _ecclesiasticalYearsCacheKey(bool? activeOnly) {
  if (activeOnly == null) {
    return '${AppConstants.catalogEcclesiasticalYearsCacheKey}_all';
  }
  return '${AppConstants.catalogEcclesiasticalYearsCacheKey}_active_${activeOnly ? 'true' : 'false'}';
}

List<T>? _readCachedList<T>({
  required LocalStorage storage,
  required String cacheKey,
  required T Function(Map<String, dynamic> json) fromJson,
}) {
  if (storage.isExpired(cacheKey, maxAge: _catalogsTtl)) {
    return null;
  }

  final raw = storage.getString(cacheKey);
  if (raw == null || raw.isEmpty) return null;

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded.map<T>((item) {
      if (item is Map) {
        return fromJson(Map<String, dynamic>.from(item));
      }
      throw FormatException('Invalid catalog cache item');
    }).toList();
  } catch (e) {
    unawaited(storage.remove(cacheKey));
    unawaited(storage.remove('${cacheKey}_cached_at'));
    return null;
  }
}

Future<void> _saveCachedList<T>({
  required LocalStorage storage,
  required String cacheKey,
  required List<T> items,
  required Map<String, dynamic> Function(T model) toJson,
}) async {
  final payload = items.map((model) => toJson(model)).toList();
  await storage.saveString(cacheKey, jsonEncode(payload));
  await storage.setCachedAt(cacheKey);
}

Future<List<T>> _getCachedOrFresh<T>({
  required LocalStorage storage,
  required String cacheKey,
  required Future<List<T>> Function() fetcher,
  required T Function(Map<String, dynamic> json) fromJson,
  required Map<String, dynamic> Function(T) toJson,
  bool forceFresh = false,
}) async {
  if (!forceFresh) {
    final cached = _readCachedList<T>(
      storage: storage,
      cacheKey: cacheKey,
      fromJson: fromJson,
    );
    if (cached != null) {
      return cached;
    }
  }

  final fresh = await fetcher();
  await _saveCachedList<T>(
    storage: storage,
    cacheKey: cacheKey,
    items: fresh,
    toJson: toJson,
  );
  return fresh;
}

/// Provider para el datasource de catálogos
final catalogsDataSourceProvider = Provider<CatalogsRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  return CatalogsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: AppConstants.baseUrl,
  );
});

/// Provider para obtener los tipos de club
final clubTypesProvider =
    FutureProvider.autoDispose<List<ClubTypeModel>>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  final storage = ref.watch(localStorageProvider);

  return _getCachedOrFresh(
    storage: storage,
    cacheKey: AppConstants.catalogClubTypesCacheKey,
    fromJson: ClubTypeModel.fromJson,
    toJson: (model) => model.toJson(),
    fetcher: () => dataSource.getClubTypes(cancelToken: cancelToken),
  );
});

/// Provider para obtener los tipos de actividad
final activityTypesProvider =
    FutureProvider.autoDispose<List<ActivityTypeModel>>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  final storage = ref.watch(localStorageProvider);

  return _getCachedOrFresh(
    storage: storage,
    cacheKey: AppConstants.catalogActivityTypesCacheKey,
    fromJson: ActivityTypeModel.fromJson,
    toJson: (model) => model.toJson(),
    fetcher: () => dataSource.getActivityTypes(cancelToken: cancelToken),
  );
});

/// Provider para obtener distritos (con filtro opcional)
final districtsProvider = FutureProvider.autoDispose
    .family<List<DistrictModel>, int?>((ref, localFieldId) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  final storage = ref.watch(localStorageProvider);

  return _getCachedOrFresh(
    storage: storage,
    cacheKey: _districtsCacheKey(localFieldId),
    fromJson: DistrictModel.fromJson,
    toJson: (model) => model.toJson(),
    fetcher: () => dataSource.getDistricts(
      localFieldId: localFieldId,
      cancelToken: cancelToken,
    ),
  );
});

/// Provider para obtener iglesias (con filtro opcional)
final churchesProvider = FutureProvider.autoDispose
    .family<List<ChurchModel>, int?>((ref, districtId) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  final storage = ref.watch(localStorageProvider);

  return _getCachedOrFresh(
    storage: storage,
    cacheKey: _churchesCacheKey(districtId),
    fromJson: ChurchModel.fromJson,
    toJson: (model) => model.toJson(),
    fetcher: () => dataSource.getChurches(
      districtId: districtId,
      cancelToken: cancelToken,
    ),
  );
});

/// Provider para obtener años eclesiásticos
final ecclesiasticalYearsProvider = FutureProvider.autoDispose
    .family<List<EcclesiasticalYearModel>, bool?>((ref, activeOnly) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  final storage = ref.watch(localStorageProvider);

  return _getCachedOrFresh(
    storage: storage,
    cacheKey: _ecclesiasticalYearsCacheKey(activeOnly),
    fromJson: EcclesiasticalYearModel.fromJson,
    toJson: (model) => model.toJson(),
    fetcher: () => dataSource.getEcclesiasticalYears(
      active: activeOnly,
      cancelToken: cancelToken,
    ),
  );
});

/// Provider para obtener el año eclesiástico actual (activo)
final currentEcclesiasticalYearProvider =
    FutureProvider.autoDispose<EcclesiasticalYearModel?>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  final storage = ref.watch(localStorageProvider);

  final cacheKey = AppConstants.catalogCurrentEcclesiasticalYearCacheKey;
  final cached = _readCachedList<EcclesiasticalYearModel>(
    storage: storage,
    cacheKey: cacheKey,
    fromJson: EcclesiasticalYearModel.fromJson,
  );

  if (cached != null && cached.isNotEmpty) {
    return cached.first;
  }

  final cachedFromList = _readCachedList<EcclesiasticalYearModel>(
    storage: storage,
    cacheKey: _ecclesiasticalYearsCacheKey(true),
    fromJson: EcclesiasticalYearModel.fromJson,
  );
  if (cachedFromList != null && cachedFromList.isNotEmpty) {
    return cachedFromList.first;
  }

  final value = await dataSource.getCurrentEcclesiasticalYear(
    cancelToken: cancelToken,
  );
  if (value == null) {
    return null;
  }

  await _saveCachedList<EcclesiasticalYearModel>(
    storage: storage,
    cacheKey: cacheKey,
    items: [value],
    toJson: (model) => model.toJson(),
  );
  return value;
});
