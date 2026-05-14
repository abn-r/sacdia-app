import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/materials_remote_data_source.dart';
import '../../data/repositories/materials_repository_impl.dart';
import '../../domain/repositories/materials_repository.dart';
import '../../domain/usecases/browse_catalog.dart';
import '../../domain/usecases/cancel_order.dart';
import '../../domain/usecases/create_order.dart';
import '../../domain/usecases/get_config.dart';
import '../../domain/usecases/get_order_detail.dart';
import '../../domain/usecases/get_order_history.dart';
import '../../domain/usecases/get_product_detail.dart';
import '../../domain/usecases/upload_receipt.dart';

// ── Infrastructure ─────────────────────────────────────────────────────────────

final materialsRemoteDataSourceProvider =
    Provider<MaterialsRemoteDataSource>((ref) {
  return MaterialsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) {
  return MaterialsRepositoryImpl(
    remoteDataSource: ref.read(materialsRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use case providers ─────────────────────────────────────────────────────────

final browseCatalogUseCaseProvider = Provider<BrowseCatalog>((ref) {
  return BrowseCatalog(ref.read(materialsRepositoryProvider));
});

final getProductDetailUseCaseProvider = Provider<GetProductDetail>((ref) {
  return GetProductDetail(ref.read(materialsRepositoryProvider));
});

final createOrderUseCaseProvider = Provider<CreateOrder>((ref) {
  return CreateOrder(ref.read(materialsRepositoryProvider));
});

final getOrderDetailUseCaseProvider = Provider<GetOrderDetail>((ref) {
  return GetOrderDetail(ref.read(materialsRepositoryProvider));
});

final getOrderHistoryUseCaseProvider = Provider<GetOrderHistory>((ref) {
  return GetOrderHistory(ref.read(materialsRepositoryProvider));
});

final uploadReceiptUseCaseProvider = Provider<UploadReceipt>((ref) {
  return UploadReceipt(ref.read(materialsRepositoryProvider));
});

final cancelOrderUseCaseProvider = Provider<CancelOrder>((ref) {
  return CancelOrder(ref.read(materialsRepositoryProvider));
});

final getConfigUseCaseProvider = Provider<GetConfig>((ref) {
  return GetConfig(ref.read(materialsRepositoryProvider));
});
