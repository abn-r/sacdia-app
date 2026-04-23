import '../../domain/entities/qr_member_token.dart';
import '../../domain/entities/qr_scan_result.dart';
import '../../domain/repositories/qr_repository.dart';
import '../datasources/qr_remote_data_source.dart';

class QrRepositoryImpl implements QrRepository {
  QrRepositoryImpl({required QrRemoteDataSource remote}) : _remote = remote;

  final QrRemoteDataSource _remote;

  @override
  Future<QrMemberToken> getMemberToken() async {
    final model = await _remote.getMemberToken();
    return model;
  }

  @override
  Future<QrScanResult> scanToken({
    required String token,
    int? activityId,
  }) {
    return _remote.scanToken(token: token, activityId: activityId);
  }
}
