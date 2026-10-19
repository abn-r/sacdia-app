import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'club_selection_providers.dart';
import 'personal_info_providers.dart';
import 'post_registration_providers.dart';

/// Resultado de una acción de post-registro ejecutada por el notifier.
class PostRegistrationFlowResult {
  final bool success;
  final String? errorMessage;

  /// Código de negocio del backend (p. ej.
  /// `POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT`), si el fallo lo trae.
  final String? errorCode;

  const PostRegistrationFlowResult._({
    required this.success,
    this.errorMessage,
    this.errorCode,
  });

  const PostRegistrationFlowResult.success() : this._(success: true);

  const PostRegistrationFlowResult.failure(String message, {String? errorCode})
      : this._(success: false, errorMessage: message, errorCode: errorCode);
}

/// Notifier para completar pasos del post-registro sin acoplar el shell a
/// repositories/data sources.
class PostRegistrationFlowNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String? get _currentUserId => ref.read(authNotifierProvider).valueOrNull?.id;

  Future<PostRegistrationFlowResult> completeStep1() async {
    final userId = _currentUserId;
    if (userId == null) {
      return PostRegistrationFlowResult.failure(
        tr('errors.user_not_authenticated'),
      );
    }

    state = const AsyncValue.loading();
    final result = await ref
        .read(postRegistrationRepositoryProvider)
        .completeStep1(userId);

    return result.fold(
      (failure) {
        final message = userErrorMessage(failure);
        state = AsyncValue.error(message, StackTrace.current);
        return PostRegistrationFlowResult.failure(
          message,
          errorCode: failure.errorCode,
        );
      },
      (_) {
        state = const AsyncValue.data(null);
        return const PostRegistrationFlowResult.success();
      },
    );
  }

  Future<PostRegistrationFlowResult> completeStep2({
    required bool canReadSensitiveData,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return PostRegistrationFlowResult.failure(
        tr('errors.user_not_authenticated'),
      );
    }

    state = const AsyncValue.loading();

    try {
      if (canReadSensitiveData) {
        await ref.read(savePersonalInfoProvider.notifier).save();
        final saveState = ref.read(savePersonalInfoProvider);
        if (saveState.hasError) {
          final error = saveState.error;
          final message = userErrorMessage(
            error,
            fallbackKey: 'post_registration.shell.error_step_failed',
          );
          state = AsyncValue.error(message, StackTrace.current);
          return PostRegistrationFlowResult.failure(
            message,
            errorCode: error is AppException ? error.errorCode : null,
          );
        }
      } else {
        await ref.read(personalInfoDataSourceProvider).completeStep2(userId);
      }

      state = const AsyncValue.data(null);
      return const PostRegistrationFlowResult.success();
    } catch (e, stack) {
      final message = userErrorMessage(e);
      state = AsyncValue.error(message, stack);
      return PostRegistrationFlowResult.failure(
        message,
        errorCode: e is AppException ? e.errorCode : null,
      );
    }
  }

  Future<PostRegistrationFlowResult> completeStep3() async {
    final userId = _currentUserId;
    if (userId == null) {
      return PostRegistrationFlowResult.failure(
        tr('errors.user_not_authenticated'),
      );
    }

    state = const AsyncValue.loading();
    ref.read(isSavingStep3Provider.notifier).state = true;

    try {
      await ref.read(clubSelectionDataSourceProvider).completeStep3(
            userId: userId,
            countryId: ref.read(selectedCountryProvider)!,
            unionId: ref.read(selectedUnionProvider)!,
            localFieldId: ref.read(selectedLocalFieldProvider)!,
            clubSectionId: ref.read(selectedClubSectionProvider)!,
          );

      state = const AsyncValue.data(null);
      return const PostRegistrationFlowResult.success();
    } on Exception catch (e, stack) {
      // 409: el paso ya estaba completo; se trata como éxito.
      if (e is AppException && e.code == 409) {
        state = const AsyncValue.data(null);
        return const PostRegistrationFlowResult.success();
      }

      final message = userErrorMessage(e);
      state = AsyncValue.error(message, stack);
      return PostRegistrationFlowResult.failure(
        message,
        errorCode: e is AppException ? e.errorCode : null,
      );
    } finally {
      ref.read(isSavingStep3Provider.notifier).state = false;
    }
  }

  /// Paso 3 alterno "Solo soy tutor de menores" (FP-60). Solo el propio
  /// usuario: la UI lo oculta mientras se actúa por un dependiente y el
  /// backend lo rechaza igualmente.
  Future<PostRegistrationFlowResult> completeGuardianOnly() async {
    final userId = _currentUserId;
    if (userId == null) {
      return PostRegistrationFlowResult.failure(
        tr('errors.user_not_authenticated'),
      );
    }

    state = const AsyncValue.loading();
    ref.read(isSavingStep3Provider.notifier).state = true;

    try {
      await ref.read(clubSelectionDataSourceProvider).completeGuardianOnly(
            userId: userId,
            countryId: ref.read(selectedCountryProvider),
            unionId: ref.read(selectedUnionProvider),
            localFieldId: ref.read(selectedLocalFieldProvider),
          );

      state = const AsyncValue.data(null);
      return const PostRegistrationFlowResult.success();
    } catch (e, stack) {
      final message = userErrorMessage(e);
      state = AsyncValue.error(message, stack);
      return PostRegistrationFlowResult.failure(
        message,
        errorCode: e is AppException ? e.errorCode : null,
      );
    } finally {
      ref.read(isSavingStep3Provider.notifier).state = false;
    }
  }
}

final postRegistrationFlowNotifierProvider =
    AsyncNotifierProvider.autoDispose<PostRegistrationFlowNotifier, void>(
  PostRegistrationFlowNotifier.new,
);
