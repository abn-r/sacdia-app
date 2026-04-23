import '../entities/qr_member_token.dart';
import '../entities/qr_scan_result.dart';

abstract class QrRepository {
  /// Requests a new member QR token from the backend. Each call rotates the
  /// token; callers should cache until [QrMemberToken.isExpired] is true.
  Future<QrMemberToken> getMemberToken();

  /// Sends a scanned QR token to the backend for validation. When
  /// [activityId] is provided the backend also registers attendance.
  Future<QrScanResult> scanToken({
    required String token,
    int? activityId,
  });
}
