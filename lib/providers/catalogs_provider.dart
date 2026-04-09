import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../shared/data/datasources/catalogs_remote_data_source.dart';
import '../shared/models/catalogs/catalogs.dart';
import 'dio_provider.dart';

/// Provider para el datasource de catálogos
final catalogsDataSourceProvider = Provider<CatalogsRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  return CatalogsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: AppConstants.baseUrl,
  );
});

/// Provider para obtener los tipos de club
final clubTypesProvider = FutureProvider.autoDispose<List<ClubTypeModel>>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getClubTypes(cancelToken: cancelToken);
});

/// Provider para obtener los tipos de actividad
final activityTypesProvider =
    FutureProvider.autoDispose<List<ActivityTypeModel>>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getActivityTypes(cancelToken: cancelToken);
});

/// Provider para obtener distritos (con filtro opcional)
final districtsProvider =
    FutureProvider.autoDispose.family<List<DistrictModel>, int?>((ref, localFieldId) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getDistricts(localFieldId: localFieldId, cancelToken: cancelToken);
});

/// Provider para obtener iglesias (con filtro opcional)
final churchesProvider =
    FutureProvider.autoDispose.family<List<ChurchModel>, int?>((ref, districtId) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getChurches(districtId: districtId, cancelToken: cancelToken);
});

/// Provider para obtener roles (con filtro opcional)
final rolesProvider =
    FutureProvider.autoDispose.family<List<RoleModel>, int?>((ref, clubTypeId) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getRoles(clubTypeId: clubTypeId, cancelToken: cancelToken);
});

/// Provider para obtener años eclesiásticos
final ecclesiasticalYearsProvider =
    FutureProvider.autoDispose.family<List<EcclesiasticalYearModel>, bool?>(
        (ref, activeOnly) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getEcclesiasticalYears(active: activeOnly, cancelToken: cancelToken);
});

/// Provider para obtener el año eclesiástico actual (activo)
final currentEcclesiasticalYearProvider =
    FutureProvider.autoDispose<EcclesiasticalYearModel?>((ref) async {
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getCurrentEcclesiasticalYear(cancelToken: cancelToken);
});
