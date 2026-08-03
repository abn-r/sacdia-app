import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/materials/data/datasources/materials_remote_data_source.dart';
import 'package:sacdia_app/features/materials/data/models/order_model.dart';
import 'package:sacdia_app/features/materials/data/repositories/materials_repository_impl.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_delivery.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_status.dart';

class _MockMaterialsRemoteDataSource extends Mock
    implements MaterialsRemoteDataSource {
  @override
  Future<OrderModel> cancelOrder(String folioOrId, String reason) =>
      super.noSuchMethod(
        Invocation.method(#cancelOrder, [folioOrId, reason]),
        returnValue: Future<OrderModel>.value(_cancelledOrder()),
      ) as Future<OrderModel>;
}

class _AlwaysConnected implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

OrderModel _cancelledOrder() => OrderModel(
      id: 'order-1',
      folioReferencia: 'SOL-001',
      status: MaterialStatus.cancelada,
      clubSectionId: 12,
      createdBy: 'user-1',
      subtotalCentavos: 1000,
      envioCentavos: 0,
      totalCentavos: 1000,
      delivery: MaterialDelivery.recoger,
      createdAt: DateTime.utc(2026, 8, 3),
      lines: const [],
      receipts: const [],
    );

void main() {
  late _MockMaterialsRemoteDataSource dataSource;
  late MaterialsRepositoryImpl repository;

  setUp(() {
    dataSource = _MockMaterialsRemoteDataSource();
    repository = MaterialsRepositoryImpl(
      remoteDataSource: dataSource,
      networkInfo: _AlwaysConnected(),
    );
  });

  group('MaterialsRepositoryImpl.cancelOrder', () {
    test('returns the cancelled order from the remote data source', () async {
      when(dataSource.cancelOrder('SOL-001', 'Cambio de planes'))
          .thenAnswer((_) async => _cancelledOrder());

      final result =
          await repository.cancelOrder('SOL-001', 'Cambio de planes');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (order) {
          expect(order.id, 'order-1');
          expect(order.status, MaterialStatus.cancelada);
        },
      );
      verify(dataSource.cancelOrder('SOL-001', 'Cambio de planes')).called(1);
    });

    test('maps a 403 authorization error to AuthFailure', () async {
      when(dataSource.cancelOrder('SOL-403', 'Cambio de planes')).thenThrow(
        AuthException(message: 'cancel_forbidden', code: 403),
      );

      final result =
          await repository.cancelOrder('SOL-403', 'Cambio de planes');

      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 403);
        },
        (_) => fail('Expected Left'),
      );
    });

    test('maps a 404 cancellation error to NotFoundFailure', () async {
      when(dataSource.cancelOrder('SOL-404', 'Cambio de planes')).thenThrow(
        NotFoundException(message: 'order_not_found', code: 404),
      );

      final result =
          await repository.cancelOrder('SOL-404', 'Cambio de planes');

      result.fold(
        (failure) {
          expect(failure, isA<NotFoundFailure>());
          expect(failure.code, 404);
        },
        (_) => fail('Expected Left'),
      );
    });

    test('maps a 422 state-transition error to ServerFailure', () async {
      when(dataSource.cancelOrder('SOL-422', 'Cambio de planes')).thenThrow(
        ServerException(message: 'state_machine_violation', code: 422),
      );

      final result =
          await repository.cancelOrder('SOL-422', 'Cambio de planes');

      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.code, 422);
        },
        (_) => fail('Expected Left'),
      );
    });
  });
}
