import 'dart:io';
import 'dart:ui' show Rect;

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/finance_export.dart';
import '../../domain/usecases/export_finances.dart';
import '../utils/finance_export_files.dart';
import 'finances_providers.dart';

/// Abre el share sheet nativo con el archivo exportado. Se inyecta para poder
/// probar el flujo sin plugins.
abstract class FinanceExportSharer {
  Future<void> share({
    required File file,
    required String fileName,
    required String mimeType,
    Rect? sharePositionOrigin,
  });
}

class SharePlusFinanceExportSharer implements FinanceExportSharer {
  const SharePlusFinanceExportSharer();

  @override
  Future<void> share({
    required File file,
    required String fileName,
    required String mimeType,
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: fileName)],
        subject: fileName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

final financeExportSharerProvider = Provider<FinanceExportSharer>(
  (ref) => const SharePlusFinanceExportSharer(),
);

/// Directorio temporal donde se escribe el archivo antes de compartirlo.
final financeExportTempDirProvider =
    Provider<Future<Directory> Function()>((ref) => getTemporaryDirectory);

/// Espera antes de borrar el archivo tras compartir (ver
/// [kFinanceExportCleanupGrace]).
final financeExportCleanupGraceProvider = Provider<Duration>(
  (ref) => kFinanceExportCleanupGrace,
);

/// Resultado de una exportación: el archivo listo para compartir o el fallo.
class FinanceExportResult {
  final File? file;
  final String? fileName;
  final String? mimeType;
  final Failure? failure;

  const FinanceExportResult.success({
    required File this.file,
    required String this.fileName,
    required String this.mimeType,
  }) : failure = null;

  const FinanceExportResult.failure(Failure this.failure)
      : file = null,
        fileName = null,
        mimeType = null;

  bool get isSuccess => file != null;
}

class FinanceExportState extends Equatable {
  /// Formato en descarga, o `null` si no hay exportación en curso.
  final FinanceExportFormat? running;

  const FinanceExportState({this.running});

  bool get isRunning => running != null;

  @override
  List<Object?> get props => [running];
}

/// Descarga el mes seleccionado y lo deja en un archivo temporal.
///
/// No comparte: abrir el share sheet necesita el `BuildContext` (origen del
/// popover en iPad), así que lo hace la vista con [financeExportSharerProvider].
class FinanceExportNotifier extends Notifier<FinanceExportState> {
  @override
  FinanceExportState build() => const FinanceExportState();

  Future<FinanceExportResult?> export(FinanceExportFormat format) =>
      ref.keepAliveDuring(() async {
        if (state.isRunning) return null;
        state = FinanceExportState(running: format);
        try {
          final clubId = await ref.read(currentClubIdProvider.future);
          if (clubId == null) {
            return const FinanceExportResult.failure(
              UnexpectedFailure(message: 'club_unavailable'),
            );
          }
          final selected = ref.read(selectedMonthProvider);
          final result = await ref.read(exportFinancesUseCaseProvider)(
            ExportFinancesParams(
              clubId: clubId,
              year: selected.year,
              month: selected.month,
              format: format,
            ),
          );

          return await result.fold<Future<FinanceExportResult>>(
            (failure) async => FinanceExportResult.failure(failure),
            (exported) async {
              final dir = await ref.read(financeExportTempDirProvider)();
              final file = await writeFinanceExportFile(
                dir,
                exported.fileName,
                exported.bytes,
              );
              return FinanceExportResult.success(
                file: file,
                fileName: exported.fileName,
                mimeType: format.mimeType,
              );
            },
          );
        } catch (e) {
          AppLogger.e('Error al exportar finanzas',
              tag: 'FinanceExport', error: e);
          // The UI maps any failure to a localized message; the raw error only
          // goes to the log.
          return const FinanceExportResult.failure(
            UnexpectedFailure(message: 'finance_export_failed'),
          );
        } finally {
          state = const FinanceExportState();
        }
      });
}

final financeExportProvider =
    NotifierProvider.autoDispose<FinanceExportNotifier, FinanceExportState>(
  FinanceExportNotifier.new,
);
