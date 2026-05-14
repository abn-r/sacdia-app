import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/receipt.dart';
import '../../domain/usecases/upload_receipt.dart';
import 'materials_providers.dart';

// ── List receipts ─────────────────────────────────────────────────────────────

/// Provider que lista los comprobantes de una orden por folio o ID.
///
/// autoDispose: se libera al salir de la pantalla. family: por folioOrId.
final receiptsProvider = FutureProvider.autoDispose
    .family<List<Receipt>, String>((ref, folioOrId) async {
  final repo = ref.watch(materialsRepositoryProvider);
  final result = await repo.listReceipts(folioOrId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (list) => list,
  );
});

// ── Upload receipt (stateful Notifier) ────────────────────────────────────────

/// Argumentos para el caso de uso de subida de comprobante.
class UploadReceiptArgs extends Equatable {
  final String folioOrId;
  final File file;
  final int montoCentavos;
  final String refBancariaDeclarada;
  final DateTime fechaPago;

  const UploadReceiptArgs({
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
class UploadReceiptState {
  final bool isLoading;
  final double progress; // 0.0 – 1.0
  final String? errorMessage;
  final Receipt? result;

  const UploadReceiptState({
    this.isLoading = false,
    this.progress = 0.0,
    this.errorMessage,
    this.result,
  });

  UploadReceiptState copyWith({
    bool? isLoading,
    double? progress,
    String? errorMessage,
    Receipt? result,
  }) {
    return UploadReceiptState(
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
class UploadReceiptNotifier extends AutoDisposeNotifier<UploadReceiptState> {
  @override
  UploadReceiptState build() => const UploadReceiptState();

  Future<void> upload(UploadReceiptArgs args) async {
    state = const UploadReceiptState(isLoading: true);

    final useCase = ref.read(uploadReceiptUseCaseProvider);
    final params = UploadReceiptParams(
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
        state = UploadReceiptState(errorMessage: failure.message);
      },
      (receipt) {
        state = UploadReceiptState(result: receipt);
      },
    );
  }

  void reset() {
    state = const UploadReceiptState();
  }
}

final uploadReceiptNotifierProvider = AutoDisposeNotifierProvider<
    UploadReceiptNotifier,
    UploadReceiptState>(UploadReceiptNotifier.new);
