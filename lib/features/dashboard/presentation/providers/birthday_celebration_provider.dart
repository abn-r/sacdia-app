import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/acting_for_session.dart';
import '../../../../core/utils/birthday_utils.dart';
import '../../../../providers/storage_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class BirthdayCelebrationState {
  final bool isBirthday;
  final bool dismissedForToday;
  final String? dismissalKey;

  const BirthdayCelebrationState({
    required this.isBirthday,
    required this.dismissedForToday,
    required this.dismissalKey,
  });

  bool get shouldShowEntryPoint => isBirthday && !dismissedForToday;
}

class BirthdayCelebrationNotifier
    extends AutoDisposeAsyncNotifier<BirthdayCelebrationState> {
  @override
  Future<BirthdayCelebrationState> build() async {
    final user = await ref.watch(authNotifierProvider.future);
    final key = birthdayDismissalKey(
      userId: user?.id,
      birthday: user?.birthday,
    );
    final isBirthday = isBirthdayToday(user?.birthday);

    if (!isBirthday || key == null) {
      return const BirthdayCelebrationState(
        isBirthday: false,
        dismissedForToday: true,
        dismissalKey: null,
      );
    }

    final prefs = ref.watch(sharedPreferencesProvider);
    return BirthdayCelebrationState(
      isBirthday: true,
      dismissedForToday: prefs.getBool(key) ?? false,
      dismissalKey: key,
    );
  }

  Future<void> dismissForToday() async {
    final current = state.valueOrNull;
    final key = current?.dismissalKey;
    if (key == null) return;

    // Actuando por un menor la bandera no se escribe en disco (FP-49): el
    // aviso queda descartado solo en memoria, mientras dure el perfil.
    if (!ref.read(actingForSessionProvider).isActing) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(key, true);
    }
    state = AsyncValue.data(
      BirthdayCelebrationState(
        isBirthday: current!.isBirthday,
        dismissedForToday: true,
        dismissalKey: key,
      ),
    );
  }
}

final birthdayCelebrationProvider = AutoDisposeAsyncNotifierProvider<
    BirthdayCelebrationNotifier, BirthdayCelebrationState>(
  BirthdayCelebrationNotifier.new,
);
