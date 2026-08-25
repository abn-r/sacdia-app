import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/camporee_orders/data/datasources/camporee_orders_remote_data_source.dart';
import 'package:sacdia_app/features/camporee_orders/data/models/camporee_order_model.dart';
import 'package:sacdia_app/features/camporee_orders/data/models/camporee_order_offering_model.dart';
import 'package:sacdia_app/features/camporee_orders/data/models/camporee_order_product_model.dart';
import 'package:sacdia_app/features/camporee_orders/data/repositories/camporee_orders_repository_impl.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/payment_orders/data/models/payment_obligation_model.dart';

class _FakeRemote implements CamporeeOrdersRemoteDataSource {
  List<Map<String, dynamic>>? lastCreateLines;
  String? lastCamporeeType;
  String? lastIdempotencyKey;

  @override
  Future<CamporeeOrderModel> createOrder({
    required int camporeeId,
    required String camporeeType,
    required List<Map<String, dynamic>> lines,
    String? idempotencyKey,
  }) async {
    lastCreateLines = lines;
    lastCamporeeType = camporeeType;
    lastIdempotencyKey = idempotencyKey;
    return CamporeeOrderModel.fromJson({
      'camporee_order_id': 'ord-1',
      'folio_reference': 'PED20260001',
      'status': 'ISSUED',
      'currency': 'MXN',
      'total_centavos': 100,
      'expires_at': '2026-09-10T00:00:00.000Z',
      'created_at': '2026-08-24T18:00:00.000Z',
      'authorized_without_proof': false,
      'distribution_status': 'NOT_STARTED',
      'lines': const [],
      'summary': const [],
    });
  }

  @override
  Future<CamporeeOrderModel> cancelOrder(String orderId) {
    throw UnimplementedError();
  }

  @override
  Future<CamporeeOrderModel> deliverLineToMember({
    required String orderId,
    required String lineId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> downloadOrderPdf(String orderId, {CancelToken? cancelToken}) {
    throw UnimplementedError();
  }

  @override
  Future<CamporeeOrderOfferingsResultModel> getOfferings({
    required int camporeeId,
    required String camporeeType,
    CancelToken? cancelToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CamporeeOrderModel> getOrder(
    String orderId, {
    CancelToken? cancelToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CamporeeOrderProofModel> getProof(String orderId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CamporeeOrderModel>> listOrders({
    int? localCamporeeId,
    int? unionCamporeeId,
    String? status,
    CancelToken? cancelToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<PaymentObligationModel>> listPendingObligations({
    int? camporeeId,
    int? unionCamporeeId,
    CancelToken? cancelToken,
  }) async {
    throw ServerException(message: 'boom', code: 500);
  }

  @override
  Future<List<CamporeeOrderProductModel>> listProducts({
    bool? active,
    CancelToken? cancelToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CamporeeOrderModel> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  test('createOrder reenvía solo el payload de líneas del dominio', () async {
    final remote = _FakeRemote();
    final repo = CamporeeOrdersRepositoryImpl(remoteDataSource: remote);

    final result = await repo.createOrder(
      camporeeId: 17,
      camporeeType: 'local',
      lines: const [
        CamporeeOrderCreateLine(
          camporeeMemberId: 801,
          offeringId: 'off-1',
          optionId: 'opt-1',
          qty: 2,
        ),
      ],
      idempotencyKey: 'idem-1',
    );

    expect(result.isRight(), isTrue);
    expect(remote.lastCamporeeType, 'local');
    expect(remote.lastIdempotencyKey, 'idem-1');
    expect(remote.lastCreateLines, [
      {
        'camporee_member_id': 801,
        'offering_id': 'off-1',
        'option_id': 'opt-1',
        'qty': 2,
      },
    ]);
  });

  test('_guard mapea ServerException a ServerFailure', () async {
    final repo = CamporeeOrdersRepositoryImpl(remoteDataSource: _FakeRemote());
    final result = await repo.listPendingObligations();
    expect(result, isA<Left<Failure, dynamic>>());
    result.fold(
      (failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.message, 'boom');
        expect(failure.code, 500);
      },
      (_) => fail('esperaba Left'),
    );
  });
}
