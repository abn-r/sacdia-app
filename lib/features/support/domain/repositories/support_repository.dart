import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/faq_item.dart';
import '../entities/support_report.dart';

/// Contrato de dominio para el feature Soporte/Ayuda.
///
/// Dos responsabilidades:
/// - Servir el FAQ bundleado (asset local, sin red).
/// - Enviar reportes al backend (`POST /support/reports`).
abstract class SupportRepository {
  /// Lee y parsea `assets/support/faq.json`. Falla con [CacheFailure] si
  /// el asset no existe o está malformado.
  Future<Either<Failure, List<FaqItem>>> loadFaq();

  /// POST /api/v1/support/reports — crea el reporte y devuelve
  /// `{ reportId, createdAt }` al éxito.
  Future<Either<Failure, SupportReportResult>> submitReport(
    SupportReportDraft draft,
  );
}
