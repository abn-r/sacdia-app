import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comprobante.dart';
import '../../domain/usecases/upload_comprobante.dart';
import 'materiales_providers.dart';

// ── List comprobantes ─────────────────────────────────────────────────────────

/// Provider que lista los comprobantes de una orden por folio o ID.
///
/// autoDispose: se libera al salir de la pantalla. family: por folioOrId.
final comprobantesProvider = FutureProvider.autoDispose
    .family<List<Comprobante>, String>((ref, folioOrId) async {
  final repo = ref.watch(materialesRepositoryProvider);
  final result = await repo.listComprobantes(folioOrId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});

// ── Upload comprobante (stateful Notifier) ────────────────────────────────────

/// Argumentos para el caso de uso de subida de comprobante.
class UploadComprobanteArgs extends Equatable {
  final String folioOrId;
  final File file;
  final int montoCentavos;
  final String refBancariaDeclarada;
  final DateTime fechaPago;

  const UploadComprobanteArgs({
    required this.folioOrId,
    required this.file,
    required this.montoCentavos,
    required this.refBancariaDeclarada,
    required this.fechaPago,
  });

  @override
  List<Object?> get props =>
      [folioOrId, file.path, montoCentavos, refBancariaDeclarada, fechaPago];
}

/// Estado del proceso de subida de comprobante.
class UploadComprobanteState {
  final bool isLoading;
  final double progress; // 0.0 – 1.0
  final String? errorMessage;
  final Comprobante? result;

  const UploadComprobanteState({
    this.isLoading = false,
    this.progress = 0.0,
    this.errorMessage,
    this.result,
  });

  UploadComprobanteState copyWith({
    bool? isLoading,
    double? progress,
    String? errorMessage,
    Comprobante? result,
  }) {
    return UploadComprobanteState(
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      result: result ?? this.result,
    );
  }
}

/// Notifier que maneja la subida de un comprobante de pago.
///
/// Expone el progreso de upload (0.0–1.0) para mostrar una barra de progreso.
class UploadComprobanteNotifier
    extends AutoDisposeNotifier<UploadComprobanteState> {
  @override
  UploadComprobanteState build() => const UploadComprobanteState();

  Future<void> upload(UploadComprobanteArgs args) async {
    state = const UploadComprobanteState(isLoading: true);

    final useCase = ref.read(uploadComprobanteUseCaseProvider);
    final params = UploadComprobanteParams(
      folioOrId: args.folioOrId,
      file: args.file,
      montoCentavos: args.montoCentavos,
      refBancariaDeclarada: args.refBancariaDeclarada,
      fechaPago: args.fechaPago,
      onProgress: (fraction) {
        state = state.copyWith(progress: fraction);
      },
    );

    final result = await useCase(params);

    result.fold(
      (failure) {
        state = UploadComprobanteState(errorMessage: failure.message);
      },
      (comprobante) {
        state = UploadComprobanteState(result: comprobante);
      },
    );
  }

  void reset() {
    state = const UploadComprobanteState();
  }
}

final uploadComprobanteNotifierProvider = AutoDisposeNotifierProvider<
    UploadComprobanteNotifier,
    UploadComprobanteState>(UploadComprobanteNotifier.new);
