import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/auth/acting_for_session.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Barra fija "Viendo como Ana · Volver a mi perfil" (FP-63).
///
/// Es visible en TODAS las pantallas mientras se actúa por un dependiente,
/// incluido el post-registro. Tocarla vuelve al perfil del tutor.
class ActingForBanner extends StatelessWidget {
  const ActingForBanner({
    super.key,
    required this.dependent,
    required this.topInset,
    required this.onBack,
  });

  final ActingDependent dependent;

  /// Alto del notch/status bar: la barra lo absorbe para que el contenido de
  /// debajo no lo repita.
  final double topInset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context);
    final name = (dependent.firstName?.trim().isNotEmpty ?? false)
        ? dependent.firstName!.trim()
        : '—';
    final label = 'family.banner.viewing_as'.tr(namedArgs: {'name': name});
    final back = 'family.banner.back'.tr();

    return Material(
      color: accent.color,
      child: Semantics(
        button: true,
        label: '$label. $back',
        excludeSemantics: true,
        child: InkWell(
          onTap: onBack,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserSwitch,
                    size: 18,
                    color: accent.onColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' · '),
                          TextSpan(
                            text: back,
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: accent.onColor,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Coloca el [ActingForBanner] sobre el navegador de toda la app.
///
/// Se monta en el `builder` del `MaterialApp`. La estructura del árbol es la
/// MISMA con o sin banner (una `Column` fija con el hijo en la misma posición),
/// de modo que entrar o salir de "actuar por" no recrea el `Navigator`.
class ActingForBannerHost extends ConsumerWidget {
  const ActingForBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dependent = ref.watch(actingDependentProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        if (dependent == null)
          const SizedBox.shrink()
        else
          ActingForBanner(
            dependent: dependent,
            topInset: topInset,
            onBack: () =>
                ref.read(authNotifierProvider.notifier).switchProfile(null),
          ),
        Expanded(
          // La barra ya ocupa el status bar: se lo quitamos al contenido.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: dependent != null,
            child: child,
          ),
        ),
      ],
    );
  }
}
