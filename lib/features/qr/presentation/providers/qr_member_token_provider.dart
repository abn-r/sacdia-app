import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/qr_remote_data_source.dart';
import '../../data/repositories/qr_repository_impl.dart';
import '../../domain/entities/qr_member_token.dart';
import '../../domain/repositories/qr_repository.dart';

final _qrDioProvider = Provider((ref) => DioClient.createDio());

final _qrRepositoryProvider = Provider<QrRepository>((ref) {
  final dio = ref.watch(_qrDioProvider);
  return QrRepositoryImpl(
    remote: QrRemoteDataSourceImpl(dio: dio, baseUrl: AppConstants.baseUrl),
  );
});

/// AsyncNotifierProvider for the authenticated member's QR token. The backend
/// issues a new token per call — callers are expected to cache until expiry.
/// Invoke [QrMemberTokenNotifier.refresh] to force a rotation (e.g. when the
/// user taps a refresh control or the cached token is about to expire).
class QrMemberTokenNotifier extends AsyncNotifier<QrMemberToken> {
  @override
  Future<QrMemberToken> build() {
    final repo = ref.read(_qrRepositoryProvider);
    return repo.getMemberToken();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      final repo = ref.read(_qrRepositoryProvider);
      return repo.getMemberToken();
    });
  }
}

final qrMemberTokenProvider =
    AsyncNotifierProvider<QrMemberTokenNotifier, QrMemberToken>(
  QrMemberTokenNotifier.new,
);
