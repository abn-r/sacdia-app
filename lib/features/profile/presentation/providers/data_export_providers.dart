import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/data_export_remote_data_source.dart';
import '../../data/repositories/data_export_repository_impl.dart';
import '../../domain/entities/data_export.dart';
import '../../domain/repositories/data_export_repository.dart';

// ── Infrastructure providers ───────────────────────────────────────────────────

final dataExportDataSourceProvider =
    Provider<DataExportRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return DataExportRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

final dataExportRepositoryProvider = Provider<DataExportRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final remoteDataSource = ref.read(dataExportDataSourceProvider);

  return DataExportRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

// ── Notifier ───────────────────────────────────────────────────────────────────

/// Notifier de exportaciones de datos (GDPR).
///
/// - [build] carga la lista desde el servidor (sin caché, siempre fresco).
/// - [refresh] fuerza recarga manual.
/// - [requestExport] solicita nueva exportación y actualiza la lista optimistamente.
/// - [download] obtiene la URL presignada de una exportación lista.
class DataExportNotifier
    extends AutoDisposeAsyncNotifier<List<DataExport>> {
  static const _tag = 'DataExportNotifier';

  @override
  Future<List<DataExport>> build() async {
    final userId = await ref.watch(
      authNotifierProvider.selectAsync((user) => user?.id),
    );
    if (userId == null) return [];

    final result = await ref.read(dataExportRepositoryProvider).list();

    return result.fold(
      (failure) {
        AppLogger.w(
          'Error al cargar exportaciones: ${failure.message}',
          tag: _tag,
        );
        // Propagar error para que la UI muestre estado de error + retry.
        throw failure;
      },
      (exports) => exports,
    );
  }

  /// Fuerza recarga desde el servidor.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Solicita una nueva exportación de datos.
  ///
  /// Retorna null en éxito o un mensaje de error localizado.
  /// En 429 el mensaje ya incluye el tiempo de espera.
  Future<String?> requestExport() async {
    final result = await ref.read(dataExportRepositoryProvider).request();

    return result.fold(
      (failure) {
        AppLogger.w(
          'Error al solicitar exportación: ${failure.message}',
          tag: _tag,
        );
        return failure.message;
      },
      (newExport) {
        AppLogger.i(
          'Exportación ${newExport.exportId} solicitada — status: ${newExport.status}',
          tag: _tag,
        );
        // Insertar al frente de la lista (más reciente primero).
        final current = state.valueOrNull ?? [];
        final updated = [newExport, ...current];
        state = AsyncData(updated);
        return null;
      },
    );
  }

  /// Obtiene la URL presignada para descargar una exportación lista.
  ///
  /// Retorna la URL en éxito, o null + un mensaje de error.
  Future<({String? url, String? error})> download(String exportId) async {
    final result =
        await ref.read(dataExportRepositoryProvider).getDownloadUrl(exportId);

    return result.fold(
      (failure) {
        AppLogger.w(
          'Error al obtener URL de descarga $exportId: ${failure.message}',
          tag: _tag,
        );
        return (url: null, error: failure.message);
      },
      (url) {
        AppLogger.i('URL de descarga obtenida para $exportId', tag: _tag);
        return (url: url, error: null);
      },
    );
  }

  /// Actualiza el estado de una exportación en la lista local.
  ///
  /// Útil para aplicar el resultado del polling sin recargar toda la lista.
  void updateExportInList(DataExport updated) {
    final current = state.valueOrNull;
    if (current == null) return;

    final newList = current
        .map((e) => e.exportId == updated.exportId ? updated : e)
        .toList();
    state = AsyncData(newList);
  }
}

/// Provider singleton de exportaciones de datos.
///
/// autoDispose: se destruye al salir de la pantalla y fuerza GET fresco
/// la próxima vez que el usuario abre la pantalla.
final dataExportProvider = AsyncNotifierProvider.autoDispose<
    DataExportNotifier, List<DataExport>>(
  DataExportNotifier.new,
);
