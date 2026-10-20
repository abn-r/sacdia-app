import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/linked_devices_remote_data_source.dart';
import '../../data/repositories/linked_devices_repository_impl.dart';
import '../../domain/entities/linked_device.dart';
import '../../domain/repositories/linked_devices_repository.dart';
import '../../domain/usecases/linked_devices_usecases.dart';
import 'family_providers.dart';

final linkedDevicesRepositoryProvider = Provider<LinkedDevicesRepository>(
  (ref) => LinkedDevicesRepositoryImpl(
    remoteDataSource: LinkedDevicesRemoteDataSourceImpl(
      dio: ref.read(dioProvider),
      baseUrl: ref.read(apiBaseUrlProvider),
    ),
  ),
);

final listLinkedDevicesUseCaseProvider = Provider<ListLinkedDevices>(
  (ref) => ListLinkedDevices(ref.read(linkedDevicesRepositoryProvider)),
);
final issueDevicePairingTokenUseCaseProvider =
    Provider<IssueDevicePairingToken>(
  (ref) => IssueDevicePairingToken(ref.read(linkedDevicesRepositoryProvider)),
);
final revokeLinkedDeviceUseCaseProvider = Provider<RevokeLinkedDevice>(
  (ref) => RevokeLinkedDevice(ref.read(linkedDevicesRepositoryProvider)),
);

/// Teléfonos vinculados de un menor y el tope de activos. Falla con el
/// [Failure] original.
///
/// `autoDispose` y sin `keepAlive`, como el resto de datos del tutor
/// (`dependentsProvider`): se suelta al salir de la pantalla y no sobrevive a un
/// cambio de perfil, así que no entra al registro de purga.
final linkedDevicesProvider =
    FutureProvider.autoDispose.family<LinkedDevices, String>((
  ref,
  dependentId,
) async {
  final result = await ref.read(listLinkedDevicesUseCaseProvider)(dependentId);
  return result.fold((failure) => throw failure, (devices) => devices);
});

/// Acciones sobre los teléfonos vinculados. Tras una mutación exitosa refresca
/// la lista y el contador del menor.
class LinkedDevicesActions {
  LinkedDevicesActions(this._ref);

  final Ref _ref;

  /// Pide un token nuevo (anula el anterior sin canjear). No toca la lista: el
  /// teléfono aparece cuando se canjea.
  Future<Either<Failure, DevicePairingToken>> issuePairingToken(
    String dependentId,
  ) =>
      _ref.read(issueDevicePairingTokenUseCaseProvider)(dependentId);

  /// Lista de teléfonos SIN pasar por el provider cacheado (la pantalla del QR
  /// la consulta periódicamente). Lanza el [Failure] si falla.
  Future<LinkedDevices> list(String dependentId) async {
    final result =
        await _ref.read(listLinkedDevicesUseCaseProvider)(dependentId);
    return result.fold((failure) => throw failure, (devices) => devices);
  }

  Future<Either<Failure, RevokedDevice>> revoke(
    String dependentId,
    String deviceId,
  ) async {
    final result = await _ref.read(revokeLinkedDeviceUseCaseProvider)(
      RevokeLinkedDeviceParams(dependentId: dependentId, deviceId: deviceId),
    );
    if (result.isRight()) refresh(dependentId);
    return result;
  }

  /// Vuelve a leer la lista, el detalle y el contador de teléfonos del menor.
  void refresh(String dependentId) {
    _ref.invalidate(linkedDevicesProvider(dependentId));
    _ref.invalidate(dependentDetailProvider(dependentId));
    _ref.invalidate(dependentsProvider);
  }
}

final linkedDevicesActionsProvider =
    Provider<LinkedDevicesActions>(LinkedDevicesActions.new);
