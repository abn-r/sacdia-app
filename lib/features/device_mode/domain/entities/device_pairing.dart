import 'package:equatable/equatable.dart';

/// Datos que el teléfono manda para canjear el token de vinculación.
class DevicePairingInput extends Equatable {
  /// Token del QR. Es un secreto de un solo uso: nunca se registra.
  final String pairingToken;

  /// Etiqueta que el tutor verá («Tablet de Ana»). Ya saneada.
  final String label;

  /// `ios` | `android`.
  final String platform;
  final String appVersion;

  const DevicePairingInput({
    required this.pairingToken,
    required this.label,
    required this.platform,
    required this.appVersion,
  });

  /// El token no entra en `props` ni en `toString`: un `Equatable` impreso o
  /// comparado en un log no debe filtrarlo.
  @override
  List<Object?> get props => [label, platform, appVersion];

  @override
  String toString() => 'DevicePairingInput(label: $label, platform: $platform)';
}

/// Sesión que el servidor entrega al vincular (`POST /auth/device/pair`).
///
/// Solo trae el nombre de pila y el avatar del menor: ni apellidos, ni datos del
/// tutor, ni otros menores.
class DevicePairingSession extends Equatable {
  final String accessToken;
  final String refreshToken;
  final int? expiresAt;
  final String? tokenType;
  final String? linkedDeviceId;
  final String? deviceLabel;
  final String userId;
  final String? userName;
  final String? userAvatar;

  const DevicePairingSession({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
    this.tokenType,
    this.linkedDeviceId,
    this.deviceLabel,
    required this.userId,
    this.userName,
    this.userAvatar,
  });

  /// Los tokens no se imprimen jamás.
  @override
  List<Object?> get props => [linkedDeviceId, userId, userName, deviceLabel];

  @override
  String toString() => 'DevicePairingSession(userId: $userId)';
}
