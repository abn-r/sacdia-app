import '../entities/qr_member_token.dart';

abstract class QrRepository {
  /// Requests a new member QR token from the backend. Each call rotates the
  /// token; callers should cache until [QrMemberToken.isExpired] is true.
  Future<QrMemberToken> getMemberToken();
}
