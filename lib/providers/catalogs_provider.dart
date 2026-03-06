import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../shared/data/datasources/catalogs_remote_data_source.dart';
import '../shared/models/catalogs/catalogs.dart';
import 'dio_provider.dart';

/// Provider para el datasource de catálogos
final catalogsDataSourceProvider = Provider<CatalogsRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return CatalogsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: AppConstants.baseUrl,
  );
});

/// Provider para obtener los tipos de club
final clubTypesProvider = FutureProvider<List<ClubTypeModel>>((ref) async {
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getClubTypes();
});

/// Provider para obtener los tipos de actividad
final activityTypesProvider =
    FutureProvider<List<ActivityTypeModel>>((ref) async {
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getActivityTypes();
});

/// Provider para obtener distritos (con filtro opcional)
final districtsProvider =
    FutureProvider.family<List<DistrictModel>, int?>((ref, localFieldId) async {
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getDistricts(localFieldId: localFieldId);
});

/// Provider para obtener iglesias (con filtro opcional)
final churchesProvider =
    FutureProvider.family<List<ChurchModel>, int?>((ref, districtId) async {
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getChurches(districtId: districtId);
});

/// Provider para obtener roles (con filtro opcional)
final rolesProvider =
    FutureProvider.family<List<RoleModel>, int?>((ref, clubTypeId) async {
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getRoles(clubTypeId: clubTypeId);
});

/// Provider para obtener años eclesiásticos
final ecclesiasticalYearsProvider =
    FutureProvider.family<List<EcclesiasticalYearModel>, bool?>(
        (ref, activeOnly) async {
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getEcclesiasticalYears(active: activeOnly);
});

/// Provider para obtener el año eclesiástico actual (activo)
final currentEcclesiasticalYearProvider =
    FutureProvider<EcclesiasticalYearModel?>((ref) async {
  final dataSource = ref.watch(catalogsDataSourceProvider);
  return dataSource.getCurrentEcclesiasticalYear();
});
