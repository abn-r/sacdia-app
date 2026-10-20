import 'package:equatable/equatable.dart';

/// Máximo de teléfonos vinculados por menor si el servidor no informa otro
/// (`limits.max_devices`, ruling #11591: 2).
const int kDefaultMaxLinkedDevices = 2;

/// Un teléfono vinculado a un menor, tal como lo ve su tutor
/// (`GET .../dependents/:id/devices`).
class LinkedDevice extends Equatable {
  final String id;
  final String label;

  /// `ios` | `android`.
  final String? platform;
  final String? appVersion;
  final DateTime? pairedAt;
  final String? pairedByDisplayName;
  final DateTime? lastSeenAt;
  final DateTime? absoluteExpiresAt;

  /// Presente solo en un teléfono ya desvinculado (el servidor lo lista 30 días).
  final DateTime? revokedAt;

  const LinkedDevice({
    required this.id,
    required this.label,
    this.platform,
    this.appVersion,
    this.pairedAt,
    this.pairedByDisplayName,
    this.lastSeenAt,
    this.absoluteExpiresAt,
    this.revokedAt,
  });

  bool get isRevoked => revokedAt != null;

  @override
  List<Object?> get props => [
        id,
        label,
        platform,
        appVersion,
        pairedAt,
        pairedByDisplayName,
        lastSeenAt,
        absoluteExpiresAt,
        revokedAt,
      ];
}

/// Lista de teléfonos de un menor y el tope de teléfonos activos.
class LinkedDevices extends Equatable {
  final List<LinkedDevice> devices;
  final int maxDevices;

  const LinkedDevices({
    this.devices = const [],
    this.maxDevices = kDefaultMaxLinkedDevices,
  });

  List<LinkedDevice> get active =>
      devices.where((d) => !d.isRevoked).toList(growable: false);

  List<LinkedDevice> get revoked =>
      devices.where((d) => d.isRevoked).toList(growable: false);

  /// Ya no caben más teléfonos activos.
  bool get isFull => active.length >= maxDevices;

  @override
  List<Object?> get props => [devices, maxDevices];
}

/// Token de vinculación de un solo uso (`POST .../devices/pairing-tokens`).
///
/// El token y el [qrPayload] son secretos: no entran en `props` ni en
/// `toString`, así que un log o un `Equatable` impreso no los filtra.
class DevicePairingToken extends Equatable {
  final String token;

  /// Lo que lleva el QR (`sacdia://pair?c=<token>`).
  final String qrPayload;
  final DateTime expiresAt;
  final DateTime issuedAt;

  const DevicePairingToken({
    required this.token,
    required this.qrPayload,
    required this.expiresAt,
    required this.issuedAt,
  });

  /// Segundos que quedan de vida a [now] (nunca negativo).
  int secondsLeftAt(DateTime now) {
    final left = expiresAt.difference(now).inSeconds;
    return left < 0 ? 0 : left;
  }

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  @override
  List<Object?> get props => [expiresAt, issuedAt];

  @override
  String toString() => 'DevicePairingToken(expiresAt: $expiresAt)';
}

/// Resultado de desvincular un teléfono.
class RevokedDevice extends Equatable {
  final String linkedDeviceId;
  final DateTime? revokedAt;

  const RevokedDevice({required this.linkedDeviceId, this.revokedAt});

  @override
  List<Object?> get props => [linkedDeviceId, revokedAt];
}
