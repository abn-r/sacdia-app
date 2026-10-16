import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/legal_remote_data_source.dart';
import '../../data/repositories/legal_repository_impl.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/entities/legal_status.dart';
import '../../domain/repositories/legal_repository.dart';

/// Código de negocio del backend cuando las versiones enviadas ya no son
/// las vigentes.
const String legalVersionMismatchCode = 'LEGAL_VERSION_MISMATCH';

/// Llaves de traducción que `LegalAcceptanceNotifier` deja en su estado de
/// error. La vista las resuelve con `tr()`.
const String legalVersionChangedKey = 'legal_gate.version_changed';
const String legalAcceptErrorKey = 'legal_gate.accept_error';

// ── Infrastructure providers ──────────────────────────────────────────────────

final legalRemoteDataSourceProvider = Provider<LegalRemoteDataSource>((ref) {
  return LegalRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepositoryImpl(
    remoteDataSource: ref.read(legalRemoteDataSourceProvider),
  );
});

// ── Data providers ────────────────────────────────────────────────────────────

/// Documentos vigentes (público). Lo consume el registro para enviar las
/// versiones que el usuario realmente vio.
final currentLegalDocumentsProvider =
    FutureProvider.autoDispose<List<LegalDocument>>((ref) async {
  final result = await ref.read(legalRepositoryProvider).getCurrentDocuments();
  return result.fold(
    (failure) => throw failure,
    (documents) => documents,
  );
});

/// Estado de aceptación del usuario autenticado. Lo consume el gate.
final myLegalStatusProvider = FutureProvider.autoDispose<LegalStatus>((
  ref,
) async {
  final result = await ref.read(legalRepositoryProvider).getMyStatus();
  return result.fold(
    (failure) => throw failure,
    (status) => status,
  );
});

// ── Acceptance notifier ───────────────────────────────────────────────────────

/// Envía la aceptación de las versiones del [LegalStatus] mostrado.
///
/// - Éxito: limpia el gate en memoria con `markLegalAccepted()`.
/// - `LEGAL_VERSION_MISMATCH`: invalida [myLegalStatusProvider] para volver a
///   pedir las versiones vigentes y deja [legalVersionChangedKey] en el error.
/// - Cualquier otro fallo: deja [legalAcceptErrorKey] en el error.
class LegalAcceptanceNotifier extends AutoDisposeAsyncNotifier<void> {
  bool _disposed = false;

  @override
  Future<void> build() async {
    ref.onDispose(() => _disposed = true);
  }

  /// Devuelve true si la aceptación quedó registrada.
  Future<bool> accept(LegalStatus status) async {
    final termsVersion = status.versionOf(LegalDocumentTypes.terms);
    final privacyVersion = status.versionOf(LegalDocumentTypes.privacy);
    if (termsVersion == null || privacyVersion == null) {
      state = AsyncValue.error(legalAcceptErrorKey, StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();
    final result = await ref.read(legalRepositoryProvider).accept(
          termsVersion: termsVersion,
          privacyVersion: privacyVersion,
        );
    if (_disposed) return result.isRight();

    return result.fold(
      (failure) {
        if (failure.errorCode == legalVersionMismatchCode) {
          ref.invalidate(myLegalStatusProvider);
          state = AsyncValue.error(legalVersionChangedKey, StackTrace.current);
        } else {
          state = AsyncValue.error(legalAcceptErrorKey, StackTrace.current);
        }
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.read(authNotifierProvider.notifier).markLegalAccepted();
        return true;
      },
    );
  }
}

final legalAcceptanceNotifierProvider =
    AsyncNotifierProvider.autoDispose<LegalAcceptanceNotifier, void>(
  LegalAcceptanceNotifier.new,
);
