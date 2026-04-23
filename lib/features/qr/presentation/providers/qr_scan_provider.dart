import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/qr_remote_data_source.dart';
import '../../data/repositories/qr_repository_impl.dart';
import '../../domain/entities/qr_scan_result.dart';
import '../../domain/repositories/qr_repository.dart';

final _qrScanDioProvider = Provider((ref) => DioClient.createDio());

final _qrScanRepositoryProvider = Provider<QrRepository>((ref) {
  final dio = ref.watch(_qrScanDioProvider);
  return QrRepositoryImpl(
    remote: QrRemoteDataSourceImpl(dio: dio, baseUrl: AppConstants.baseUrl),
  );
});

/// Submits a scanned token to the backend. One-shot use per scan — callers
/// should map to their own UI state, not reuse across scans.
class QrScanNotifier extends AutoDisposeAsyncNotifier<QrScanResult?> {
  @override
  Future<QrScanResult?> build() async => null;

  Future<void> submit({required String token, int? activityId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(_qrScanRepositoryProvider);
      return repo.scanToken(token: token, activityId: activityId);
    });
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final qrScanProvider =
    AsyncNotifierProvider.autoDispose<QrScanNotifier, QrScanResult?>(
  QrScanNotifier.new,
);
