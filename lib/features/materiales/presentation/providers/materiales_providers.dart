import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/materiales_remote_data_source.dart';
import '../../data/repositories/materiales_repository_impl.dart';
import '../../domain/repositories/materiales_repository.dart';
import '../../domain/usecases/browse_catalog.dart';
import '../../domain/usecases/cancel_order.dart';
import '../../domain/usecases/create_order.dart';
import '../../domain/usecases/get_config.dart';
import '../../domain/usecases/get_order_detail.dart';
import '../../domain/usecases/get_order_history.dart';
import '../../domain/usecases/get_product_detail.dart';
import '../../domain/usecases/upload_comprobante.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final materialesRemoteDataSourceProvider =
    Provider<MaterialesRemoteDataSource>((ref) {
  return MaterialesRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final materialesRepositoryProvider = Provider<MaterialesRepository>((ref) {
  return MaterialesRepositoryImpl(
    remoteDataSource: ref.read(materialesRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use case providers ─────────────────────────────────────────────────────────

final browseCatalogUseCaseProvider = Provider<BrowseCatalog>((ref) {
  return BrowseCatalog(ref.read(materialesRepositoryProvider));
});

final getProductDetailUseCaseProvider = Provider<GetProductDetail>((ref) {
  return GetProductDetail(ref.read(materialesRepositoryProvider));
});

final createOrderUseCaseProvider = Provider<CreateOrder>((ref) {
  return CreateOrder(ref.read(materialesRepositoryProvider));
});

final getOrderDetailUseCaseProvider = Provider<GetOrderDetail>((ref) {
  return GetOrderDetail(ref.read(materialesRepositoryProvider));
});

final getOrderHistoryUseCaseProvider = Provider<GetOrderHistory>((ref) {
  return GetOrderHistory(ref.read(materialesRepositoryProvider));
});

final uploadComprobanteUseCaseProvider = Provider<UploadComprobante>((ref) {
  return UploadComprobante(ref.read(materialesRepositoryProvider));
});

final cancelOrderUseCaseProvider = Provider<CancelOrder>((ref) {
  return CancelOrder(ref.read(materialesRepositoryProvider));
});

final getConfigUseCaseProvider = Provider<GetConfig>((ref) {
  return GetConfig(ref.read(materialesRepositoryProvider));
});
