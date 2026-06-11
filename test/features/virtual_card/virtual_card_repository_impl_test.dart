import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/virtual_card/data/datasources/virtual_card_remote_data_source.dart';
import 'package:sacdia_app/features/virtual_card/data/models/virtual_card_model.dart';
import 'package:sacdia_app/features/virtual_card/data/repositories/virtual_card_repository_impl.dart';

class _FakeNetworkInfo implements NetworkInfo {
  _FakeNetworkInfo(this.connected);

  final bool connected;

  @override
  Future<bool> get isConnected async => connected;
}

class _FakeVirtualCardRemoteDataSource implements VirtualCardRemoteDataSource {
  _FakeVirtualCardRemoteDataSource(this.error);

  final Object error;

  @override
  Future<VirtualCardModel> getVirtualCard({CancelToken? cancelToken}) async {
    throw error;
  }
}

void main() {
  test('rethrows connection errors so callers can fall back safely', () async {
    final repo = VirtualCardRepositoryImpl(
      remoteDataSource: _FakeVirtualCardRemoteDataSource(
        ConnectionException(message: 'timeout'),
      ),
      networkInfo: _FakeNetworkInfo(true),
    );

    await expectLater(
      repo.getRemoteCard(),
      throwsA(isA<ConnectionException>()),
    );
  });

  test('keeps functional server errors as errors instead of fallback signals',
      () async {
    final repo = VirtualCardRepositoryImpl(
      remoteDataSource: _FakeVirtualCardRemoteDataSource(
        ServerException(message: 'Forbidden', code: 403),
      ),
      networkInfo: _FakeNetworkInfo(true),
    );

    await expectLater(
      repo.getRemoteCard(),
      throwsA(
        isA<ServerException>().having((e) => e.code, 'code', 403),
      ),
    );
  });
}
