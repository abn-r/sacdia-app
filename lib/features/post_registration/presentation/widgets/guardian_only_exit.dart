import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/auth/presentation/providers/acting_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/family/presentation/family_error_messages.dart';
import 'package:sacdia_app/features/family/presentation/widgets/family_prompt_host.dart';

import '../providers/post_registration_flow_providers.dart';

/// Salida "Solo soy tutor de menores" del paso 3 (FP-60).
///
/// Un adulto sin club propio cierra su post-registro y va directo a Mi familia.
///
/// - Se oculta mientras se actúa por un dependiente: ese post-registro es el
///   del menor y el backend tampoco lo permite (sin `@ActingScope`).
/// - Un menor de edad recibe `POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT` (422).
class GuardianOnlyExit extends ConsumerStatefulWidget {
  const GuardianOnlyExit({super.key});

  @override
  ConsumerState<GuardianOnlyExit> createState() => _GuardianOnlyExitState();
}

class _GuardianOnlyExitState extends ConsumerState<GuardianOnlyExit> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    final confirmed = await SacDialog.show(
      context,
      title: 'post_registration.guardian_only.confirm_title'.tr(),
      content: 'post_registration.guardian_only.confirm_body'.tr(),
      confirmLabel: 'post_registration.guardian_only.confirm_action'.tr(),
      icon: HugeIcons.strokeRoundedUserGroup,
    );
    if (confirmed != true || !mounted) return;

    final userId = ref.read(authNotifierProvider).valueOrNull?.id;
    setState(() => _busy = true);
    final result = await ref
        .read(postRegistrationFlowNotifierProvider.notifier)
        .completeGuardianOnly();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      final key = familyErrorKey(result.errorCode);
      SacSnackBar.show(
        context,
        key != null
            ? key.tr()
            : 'post_registration.guardian_only.error_generic'.tr(),
        isError: true,
      );
      return;
    }

    // El destino ya es Mi familia: el aviso de una sola vez sobra.
    ref.read(familyPromptSuppressedProvider.notifier).state = true;
    final router = GoRouter.of(context);
    final auth = ref.read(authNotifierProvider.notifier);
    auth.markPostRegisterComplete(forUserId: userId);
    router.go(RouteNames.homeDashboard);
    router.push(RouteNames.family);
    // Sin esperar: el estado en memoria ya basta para que el router deje el
    // post-registro; /auth/me solo completa `family` y compañía.
    auth.refreshCurrentUser(keepCurrentOnFailure: true);
  }

  @override
  Widget build(BuildContext context) {
    final acting = ref.watch(actingDependentProvider) != null ||
        ref.watch(
          authNotifierProvider.select((v) => v.valueOrNull?.actingFor != null),
        );
    if (acting) return const SizedBox.shrink();

    // Mantiene vivo el notifier (autoDispose) durante la llamada.
    ref.watch(postRegistrationFlowNotifierProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'post_registration.guardian_only.hint'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          SacButton.outline(
            text: 'post_registration.guardian_only.action'.tr(),
            icon: HugeIcons.strokeRoundedUserGroup,
            isLoading: _busy,
            onPressed: _busy ? null : _onPressed,
          ),
        ],
      ),
    );
  }
}
