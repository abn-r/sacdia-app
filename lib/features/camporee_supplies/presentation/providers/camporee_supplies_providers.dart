import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../camporee_orders/domain/entities/camporee_order.dart';
import '../../../camporee_orders/presentation/providers/camporee_orders_providers.dart';
import '../../data/datasources/camporee_supplies_remote_data_source.dart';
import '../../data/repositories/camporee_supplies_repository_impl.dart';
import '../../domain/entities/camporee_supply_plan.dart';
import '../../domain/repositories/camporee_supplies_repository.dart';

final camporeeSuppliesRemoteDataSourceProvider =
    Provider<CamporeeSuppliesRemoteDataSource>((ref) {
  return CamporeeSuppliesRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final camporeeSuppliesRepositoryProvider =
    Provider<CamporeeSuppliesRepository>((ref) {
  return CamporeeSuppliesRepositoryImpl(
    remoteDataSource: ref.read(camporeeSuppliesRemoteDataSourceProvider),
  );
});

class CamporeeSuppliesScope extends Equatable {
  final int camporeeId;
  final CamporeeKind type;

  const CamporeeSuppliesScope({
    required this.camporeeId,
    required this.type,
  });

  factory CamporeeSuppliesScope.fromQuery(int camporeeId, String? type) {
    return CamporeeSuppliesScope(
      camporeeId: camporeeId,
      type: camporeeKindFromQuery(type),
    );
  }

  @override
  List<Object?> get props => [camporeeId, type];
}

final camporeeSupplyPlanProvider = FutureProvider.autoDispose
    .family<CamporeeSupplyPlanEnvelope, CamporeeSuppliesScope>(
        (ref, scope) async {
  final result = await ref.read(camporeeSuppliesRepositoryProvider).getPlan(
        camporeeId: scope.camporeeId,
        camporeeType: scope.type,
      );
  return result.fold((failure) => throw failure, (envelope) => envelope);
});

String camporeeSuppliesErrorMessage(Object error) {
  if (error is Failure) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}
