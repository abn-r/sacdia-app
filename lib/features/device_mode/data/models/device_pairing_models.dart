import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/device_pairing.dart';

/// Parseo de la respuesta de `POST /auth/device/pair`.
///
/// Contrato (diseño §8.1): `{accessToken, refreshToken, expiresAt, tokenType,
/// device:{linked_device_id, label}, user:{id, name, avatar}}`. Se acepta con o
/// sin el envoltorio `{data: ...}`.
class DevicePairingJson {
  DevicePairingJson._();

  static DevicePairingSession session(Object? raw) {
    final root = raw is Map ? raw : null;
    final data =
        root != null && root['data'] is Map ? root['data'] as Map : root;
    if (data == null) {
      throw ServerException(message: tr('errors.server_error'));
    }
    final access = data['accessToken'] ?? data['access_token'];
    final refresh = data['refreshToken'] ?? data['refresh_token'];
    final user = data['user'];
    final userId = user is Map ? user['id']?.toString() : null;
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      throw ServerException(message: tr('errors.server_error'));
    }
    final device = data['device'];
    final expiresAt = data['expiresAt'] ?? data['expires_at'];
    return DevicePairingSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt is num ? expiresAt.toInt() : null,
      tokenType: (data['tokenType'] ?? data['token_type'])?.toString(),
      linkedDeviceId:
          device is Map ? device['linked_device_id']?.toString() : null,
      deviceLabel: device is Map ? device['label']?.toString() : null,
      userId: userId,
      userName: user is Map ? user['name']?.toString() : null,
      userAvatar: user is Map ? user['avatar']?.toString() : null,
    );
  }
}
