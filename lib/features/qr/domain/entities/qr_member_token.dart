import 'package:equatable/equatable.dart';

/// Short-lived signed token that represents the authenticated member in a QR
/// payload. Clients encode [token] directly into the QR code; scan endpoints
/// validate the HS256 signature and enforce audience `sacdia:qr-member`.
class QrMemberToken extends Equatable {
  const QrMemberToken({
    required this.token,
    required this.expiresAt,
    required this.expiresIn,
  });

  final String token;
  final DateTime expiresAt;
  final int expiresIn;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  @override
  List<Object?> get props => [token, expiresAt, expiresIn];
}
