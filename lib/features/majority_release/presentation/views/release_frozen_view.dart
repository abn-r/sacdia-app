import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../providers/majority_release_providers.dart';
import '../widgets/release_account_actions.dart';

/// Adulto liberado y CONGELADO (Fase 4): sus datos siguen guardados y ocultos
/// del club. NUNCA se borran solos (R6): solo la propia persona puede pedirlo.
///
/// Ofrece volver (aceptar y, si falta, agregar un correo descongela: R1, sin
/// plazo), exportar sus datos y borrar la cuenta. No muestra ninguna fecha de
/// borrado porque no existe.
class ReleaseFrozenView extends ConsumerWidget {
  const ReleaseFrozenView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final textTheme = Theme.of(context).textTheme;
    final release = ref.watch(releaseInfoProvider);
    final frozenAt = release?.frozenAt;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: Responsive.formPadding(context),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: Responsive.maxFormWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: accent.color.withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD),
                        ),
                        alignment: Alignment.center,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedUserLock01,
                          size: 28,
                          color: accent.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'release.frozen.title'.tr(),
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'release.frozen.body'.tr(),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    if (frozenAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'release.frozen.since'.tr(namedArgs: {
                          'date': SacDateFormatter.dateTime(frozenAt),
                        }),
                        key: const ValueKey('release_frozen_since'),
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SacButton(
                      key: const ValueKey('release_frozen_claim'),
                      text: 'release.frozen.claim'.tr(),
                      variant: SacButtonVariant.primary,
                      size: SacButtonSize.large,
                      fullWidth: true,
                      borderRadius: AppTheme.radiusFull,
                      onPressed: () => context.go(RouteNames.release),
                    ),
                    const SizedBox(height: 12),
                    const ReleaseAccountActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
