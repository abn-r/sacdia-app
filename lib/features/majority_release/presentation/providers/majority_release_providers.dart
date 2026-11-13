import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/keep_alive_during.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/entities/principal_info.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../legal/domain/entities/legal_document.dart';
import '../../../legal/domain/entities/legal_status.dart';
import '../../../legal/presentation/providers/legal_providers.dart';
import '../../data/datasources/majority_release_remote_data_source.dart';
import '../../data/repositories/majority_release_repository_impl.dart';
import '../../domain/entities/released_entry.dart';
import '../../domain/repositories/majority_release_repository.dart';
import '../majority_release_error_messages.dart';

// ── Infraestructura ──────────────────────────────────────────────────────────

final majorityReleaseRemoteDataSourceProvider =
    Provider<MajorityReleaseRemoteDataSource>((ref) {
  return MajorityReleaseRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final majorityReleaseRepositoryProvider =
    Provider<MajorityReleaseRepository>((ref) {
  return MajorityReleaseRepositoryImpl(
    remoteDataSource: ref.read(majorityReleaseRemoteDataSourceProvider),
  );
});

// ── Datos derivados ──────────────────────────────────────────────────────────

/// `principal.release` de la sesión (derivado de `/auth/me`; sin estado propio).
/// Nulo si la persona no está liberada.
final releaseInfoProvider = Provider.autoDispose<ReleaseInfo?>((ref) {
  return ref.watch(authNotifierProvider.select((v) => v.value?.release));
});

/// Historial de personas liberadas del ex tutor. Solo se pide al abrir la
/// pantalla (oculto por defecto en Mi familia).
final guardianReleasedHistoryProvider =
    FutureProvider.autoDispose<List<ReleasedEntry>>((ref) async {
  final result =
      await ref.read(majorityReleaseRepositoryProvider).getReleasedHistory();
  return result.fold((failure) => throw failure, (entries) => entries);
});

// ── Controlador del flujo /release ───────────────────────────────────────────

/// Estado de las acciones de la pantalla de liberación.
class ReleaseActionState {
  /// Hay una aceptación en vuelo.
  final bool accepting;

  /// Hay un alta de correo en vuelo.
  final bool addingEmail;

  /// Llave `errors.*`/`release.*` o mensaje ya traducido del último fallo de
  /// aceptación (la vista lo muestra tal cual).
  final String? acceptError;

  /// Mensaje traducido del último fallo del correo (inline, p. ej. 409).
  final String? emailError;

  /// El correo se agregó en esta pantalla: muestra la pista de verificación.
  final bool emailAdded;

  const ReleaseActionState({
    this.accepting = false,
    this.addingEmail = false,
    this.acceptError,
    this.emailError,
    this.emailAdded = false,
  });

  bool get busy => accepting || addingEmail;

  ReleaseActionState copyWith({
    bool? accepting,
    bool? addingEmail,
    String? Function()? acceptError,
    String? Function()? emailError,
    bool? emailAdded,
  }) =>
      ReleaseActionState(
        accepting: accepting ?? this.accepting,
        addingEmail: addingEmail ?? this.addingEmail,
        acceptError: acceptError != null ? acceptError() : this.acceptError,
        emailError: emailError != null ? emailError() : this.emailError,
        emailAdded: emailAdded ?? this.emailAdded,
      );
}

/// Acciones de `/release`: aceptar los documentos vigentes y agregar el correo.
///
/// Los dos métodos esperan red y luego tocan `ref`/`state`, así que van dentro
/// de `ref.keepAliveDuring` (Riverpod 3: si nadie observa el provider durante el
/// `await`, se desecharía y el siguiente uso lanzaría).
///
/// Al terminar cada acción se relee `/auth/me` (`refreshAuthorization`): el
/// servidor decide si la persona ya completó (acepta Y tiene correo) y el router
/// la saca de aquí; la app nunca lo deduce.
class ReleaseController extends Notifier<ReleaseActionState> {
  @override
  ReleaseActionState build() => const ReleaseActionState();

  /// Acepta con las versiones del [status] que la persona vio.
  /// Devuelve `true` si quedó registrada.
  Future<bool> accept(LegalStatus status) => ref.keepAliveDuring(() async {
        final termsVersion = status.versionOf(LegalDocumentTypes.terms);
        final privacyVersion = status.versionOf(LegalDocumentTypes.privacy);
        if (termsVersion == null || privacyVersion == null) {
          state = state.copyWith(
            acceptError: () => legalAcceptErrorKey,
          );
          return false;
        }
        state = state.copyWith(accepting: true, acceptError: () => null);
        final result = await ref.read(legalRepositoryProvider).accept(
              termsVersion: termsVersion,
              privacyVersion: privacyVersion,
            );
        return result.fold(
          (failure) {
            if (failure.errorCode == legalVersionMismatchCode) {
              ref.invalidate(myLegalStatusProvider);
              state = state.copyWith(
                accepting: false,
                acceptError: () => legalVersionChangedKey,
              );
            } else if (isStaleReleaseState(failure)) {
              state = state.copyWith(
                accepting: false,
                acceptError: () => null,
              );
              _resync();
            } else {
              state = state.copyWith(
                accepting: false,
                acceptError: () => legalAcceptErrorKey,
              );
            }
            return false;
          },
          (_) {
            state = state.copyWith(accepting: false, acceptError: () => null);
            _resync();
            return true;
          },
        );
      });

  /// Agrega el [email] (sin verificar basta). Los errores quedan en
  /// [ReleaseActionState.emailError], ya traducidos por `code`.
  Future<bool> addEmail(String email) => ref.keepAliveDuring(() async {
        state = state.copyWith(addingEmail: true, emailError: () => null);
        final result =
            await ref.read(majorityReleaseRepositoryProvider).addEmail(email);
        return result.fold(
          (failure) {
            if (isStaleReleaseState(failure)) {
              // El servidor ya lo tiene: se vuelve a leer y se sigue.
              state = state.copyWith(addingEmail: false);
              _resync();
              return false;
            }
            state = state.copyWith(
              addingEmail: false,
              emailError: () => majorityReleaseErrorMessage(failure),
            );
            return false;
          },
          (_) {
            state = state.copyWith(addingEmail: false, emailAdded: true);
            _resync();
            return true;
          },
        );
      });

  void _resync() {
    ref
        .read(authNotifierProvider.notifier)
        .refreshAuthorization(minInterval: Duration.zero)
        .ignore();
  }
}

final releaseControllerProvider =
    NotifierProvider.autoDispose<ReleaseController, ReleaseActionState>(
  ReleaseController.new,
);

// ── Canje del código de acceso (público) ─────────────────────────────────────

/// Estado del canje: en vuelo, error ya traducido o éxito.
class AdultClaimState {
  final bool submitting;
  final String? error;
  final bool success;

  const AdultClaimState({
    this.submitting = false,
    this.error,
    this.success = false,
  });
}

class AdultClaimController extends Notifier<AdultClaimState> {
  @override
  AdultClaimState build() => const AdultClaimState();

  /// Canjea [code] con [email] y [password]. Éxito = credenciales creadas (sin
  /// sesión): la vista lleva al login con el correo ya escrito.
  Future<bool> redeem({
    required String code,
    required String email,
    required String password,
  }) =>
      ref.keepAliveDuring(() async {
        state = const AdultClaimState(submitting: true);
        final result =
            await ref.read(majorityReleaseRepositoryProvider).redeemAdultClaim(
                  code: code,
                  email: email,
                  password: password,
                );
        return result.fold(
          (failure) {
            state = AdultClaimState(
              error: majorityReleaseErrorMessage(failure),
            );
            return false;
          },
          (_) {
            state = const AdultClaimState(success: true);
            return true;
          },
        );
      });
}

final adultClaimControllerProvider =
    NotifierProvider.autoDispose<AdultClaimController, AdultClaimState>(
  AdultClaimController.new,
);
