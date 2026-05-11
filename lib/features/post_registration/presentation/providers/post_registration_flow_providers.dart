import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'club_selection_providers.dart';
import 'personal_info_providers.dart';
import 'post_registration_providers.dart';

/// Resultado de una acción de post-registro ejecutada por el notifier.
class PostRegistrationFlowResult {
  final bool success;
  final String? errorMessage;

  const PostRegistrationFlowResult._({
    required this.success,
    this.errorMessage,
  });

  const PostRegistrationFlowResult.success() : this._(success: true);

  const PostRegistrationFlowResult.failure(String message)
      : this._(success: false, errorMessage: message);
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
        state = AsyncValue.error(failure.message, StackTrace.current);
        return PostRegistrationFlowResult.failure(failure.message);
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
          final message = saveState.error?.toString() ??
              tr('post_registration.shell.error_step_failed');
          state = AsyncValue.error(message, StackTrace.current);
          return PostRegistrationFlowResult.failure(message);
        }
      } else {
        await ref.read(personalInfoDataSourceProvider).completeStep2(userId);
      }

      state = const AsyncValue.data(null);
      return const PostRegistrationFlowResult.success();
    } catch (e, stack) {
      final message = e.toString().replaceFirst('Exception: ', '');
      state = AsyncValue.error(message, stack);
      return PostRegistrationFlowResult.failure(message);
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
            classId: ref.read(selectedClassProvider)!,
          );

      state = const AsyncValue.data(null);
      return const PostRegistrationFlowResult.success();
    } on Exception catch (e, stack) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (message.contains('409')) {
        state = const AsyncValue.data(null);
        return const PostRegistrationFlowResult.success();
      }

      state = AsyncValue.error(message, stack);
      return PostRegistrationFlowResult.failure(message);
    } finally {
      ref.read(isSavingStep3Provider.notifier).state = false;
    }
  }
}

final postRegistrationFlowNotifierProvider =
    AsyncNotifierProvider.autoDispose<PostRegistrationFlowNotifier, void>(
  PostRegistrationFlowNotifier.new,
);
