import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/certification_requirement_component.dart';

/// Provider para el [Box] de Hive donde se guardan los borradores locales de
/// requisitos de certificación.
///
/// Debe ser anulado en `main()` (vía `Hive.openBox<String>`) antes de
/// `runApp`, siguiendo el mismo patrón que [sharedPreferencesProvider]. En
/// tests, anular con un box abierto sobre un directorio temporal
/// (`Hive.init(tempDir.path)`).
final certificationDraftBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError(
    'certificationDraftBoxProvider debe ser anulado durante la inicialización',
  );
});

/// Fuente de datos local (Hive) para borradores de requisitos de
/// certificación — Task 12.
///
/// Guarda, por cada requisito en edición, las respuestas de componentes
/// capturadas por el usuario ANTES de que se persistan en el backend (vía
/// `saveRequirementDraft`). Esto permite restaurar texto/selecciones si el
/// usuario cierra la app a medio llenar un requisito, sin prometer envío
/// offline: solo el borrador local se restaura; el envío (`submit`) siempre
/// requiere red.
///
/// Clave: `"$enrollmentId:$sectionId"` — se usa `enrollmentId` (no
/// `certificationId`) porque el borrador es propio de una inscripción
/// concreta; si el usuario se da de baja y se vuelve a inscribir, no debe
/// heredar un borrador de una inscripción anterior aunque la certificación
/// sea la misma.
class CertificationDraftLocalDataSource {
  static const boxName = 'certification_requirement_drafts';
  static const _tag = 'CertificationDraftLocalDS';

  final Box<String> box;

  const CertificationDraftLocalDataSource(this.box);

  static String keyFor(int enrollmentId, int sectionId) =>
      '$enrollmentId:$sectionId';

  /// Lee el borrador guardado localmente, si existe. Devuelve `null` si no
  /// hay borrador o si el contenido guardado está corrupto (nunca lanza).
  Map<int, CertificationComponentDraftInput>? getDraft(
    int enrollmentId,
    int sectionId,
  ) {
    final raw = box.get(keyFor(enrollmentId, sectionId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <int, CertificationComponentDraftInput>{};
      for (final entry in decoded.entries) {
        final componentId = int.tryParse(entry.key);
        if (componentId == null) continue;
        final json = entry.value as Map<String, dynamic>;
        result[componentId] = CertificationComponentDraftInput(
          componentId: componentId,
          textValue: json['text_value'] as String?,
          attestationConfirmed: json['attestation_confirmed'] as bool?,
          linkedUserHonorId: (json['linked_user_honor_id'] as num?)?.toInt(),
          linkedActivityId: (json['linked_activity_id'] as num?)?.toInt(),
        );
      }
      return result;
    } catch (e) {
      AppLogger.w('Borrador local corrupto, se descarta', tag: _tag, error: e);
      return null;
    }
  }

  /// Guarda (sobrescribe) el borrador local completo del requisito.
  Future<void> saveDraft(
    int enrollmentId,
    int sectionId,
    Map<int, CertificationComponentDraftInput> values,
  ) async {
    final encoded = jsonEncode(
      values.map((componentId, input) =>
          MapEntry(componentId.toString(), input.toJson())),
    );
    await box.put(keyFor(enrollmentId, sectionId), encoded);
  }

  /// Elimina el borrador local — se llama tras guardar/enviar exitosamente
  /// al backend, o si el usuario descarta los cambios.
  Future<void> clearDraft(int enrollmentId, int sectionId) async {
    await box.delete(keyFor(enrollmentId, sectionId));
  }
}
