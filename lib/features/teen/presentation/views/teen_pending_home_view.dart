import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../auth/domain/entities/principal_info.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/utils/change_password_flow.dart';
import '../../../profile/presentation/views/edit_profile_view.dart';
import '../../domain/entities/teen_supervision.dart';
import '../providers/teen_providers.dart';
import '../teen_error_messages.dart';

/// Comparte el texto del código (inyectable para probar sin el plugin).
typedef ShareText = Future<void> Function(String text);

Future<void> _defaultShare(String text) async {
  await Share.share(text);
}

/// Pantalla única del modo restringido de un adolescente sin tutor verificado
/// (FP3-31).
///
/// Muestra el estado, un botón para generar el código que el tutor canjea
/// (copiar / compartir, vence en 72 h), el tutor ya vinculado con la opción de
/// quitarlo mientras nadie lo haya verificado, y los días que quedan antes de
/// que la cuenta se elimine. Nada de datos del club: lo único que puede hacer
/// además es completar su perfil, cambiar su contraseña y salir.
class TeenPendingHomeView extends ConsumerStatefulWidget {
  const TeenPendingHomeView({
    super.key,
    this.onShare = _defaultShare,
    this.clock = DateTime.now,
  });

  final ShareText onShare;

  /// Reloj inyectable para la cuenta atrás.
  final DateTime Function() clock;

  @override
  ConsumerState<TeenPendingHomeView> createState() =>
      _TeenPendingHomeViewState();
}

class _TeenPendingHomeViewState extends ConsumerState<TeenPendingHomeView> {
  bool _busy = false;

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    SacSnackBar.show(context, message, isError: isError);
  }

  String _when(DateTime date) => DateFormat.yMMMd(context.locale.toString())
      .add_jm()
      .format(date.toLocal());

  Future<void> _refresh() async {
    ref.invalidate(supervisionStatusProvider);
    // Si mientras tanto el director verificó, el router cambia de pantalla.
    await ref.read(authNotifierProvider.notifier).refreshSupervision();
    try {
      await ref.read(supervisionStatusProvider.future);
    } catch (_) {
      // El error se muestra en la propia tarjeta.
    }
  }

  Future<void> _generate() async {
    final ok = await ref.read(teenLinkCodeProvider.notifier).issue();
    if (!mounted || ok) return;
    _toast(
      teenErrorMessage(ref.read(teenLinkCodeProvider).error),
      isError: true,
    );
  }

  Future<void> _copy(TeenLinkCode code) async {
    await Clipboard.setData(ClipboardData(text: code.code));
    _toast('teen.pending.code_copied'.tr());
  }

  Future<void> _share(TeenLinkCode code) {
    return widget.onShare(
      'teen.pending.share_message'.tr(namedArgs: {
        'code': code.code,
        'when': _when(code.expiresAt),
      }),
    );
  }

  Future<void> _remove(TeenGuardian guardian) async {
    final id = guardian.guardianshipId;
    if (id == null) return;
    final confirmed = await SacDialog.show(
      context,
      title: 'teen.pending.remove_title'
          .tr(namedArgs: {'name': guardian.displayName}),
      content: 'teen.pending.remove_body'.tr(),
      confirmLabel: 'teen.pending.remove_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(teenActionsProvider).revokePendingLink(id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => _toast(teenErrorMessage(failure), isError: true),
      (_) => _toast('teen.pending.removed'.tr()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Un código canjeado o vencido deja de existir también en memoria: si no, un
    // código nuevo del servidor lo «resucitaría» con el texto viejo.
    ref.listen(supervisionStatusProvider, (_, next) {
      if (next.isLoading || next.hasError) return;
      if (next.valueOrNull?.openLinkCode == null) {
        ref.read(teenLinkCodeProvider.notifier).clear();
      }
    });
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final hPad = Responsive.horizontalPadding(context);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final supervisionAsync = ref.watch(supervisionStatusProvider);
    final codeState = ref.watch(teenLinkCodeProvider);
    final generating = codeState.isLoading;

    final fromServer = supervisionAsync.valueOrNull;
    // El servidor manda: el texto del código que se generó en esta pantalla solo
    // se muestra mientras `open_link_code` siga abierto. Si ya se canjeó (o
    // venció) la tarjeta desaparece, aunque la respuesta del POST siga en
    // memoria. Mientras se relee o si la lectura falla no se sabe: se conserva.
    final serverSaysNoOpenCode = fromServer != null &&
        !supervisionAsync.isLoading &&
        !supervisionAsync.hasError &&
        fromServer.openLinkCode == null;
    final issued = serverSaysNoOpenCode ? null : codeState.valueOrNull;
    final fromMe = user?.principal?.supervision;
    final now = widget.clock();
    // `/auth/me` ya trae el reloj y los tutores; el endpoint propio añade los
    // ids de tutoría (para quitar un vínculo) y el código abierto.
    final daysLeft = fromMe?.daysLeftAt(now) ?? fromServer?.daysLeftAt(now);
    final guardians = fromServer?.guardians ??
        [
          for (final g in fromMe?.guardians ?? const <SupervisionGuardian>[])
            TeenGuardian(
              guardianshipId: g.guardianshipId,
              displayName: g.displayName,
              relationshipTypeName: g.relationshipTypeName,
              verified: g.consentStatus == 'verified',
              consentPending: g.consentStatus == 'pending',
            ),
        ];

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 32),
            children: [
              Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedUserLock01,
                  size: 44,
                  color: SacAccent.of(context).color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'teen.pending.title'.tr(),
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'teen.pending.subtitle'.tr(),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                  height: 1.45,
                ),
              ),
              if (daysLeft != null) ...[
                const SizedBox(height: 16),
                _Countdown(daysLeft: daysLeft),
              ],
              const SizedBox(height: 20),
              _SectionLabel(label: 'teen.pending.code_title'.tr()),
              const SizedBox(height: 8),
              SacCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'teen.pending.code_hint'.tr(),
                      style: textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (issued != null) ...[
                      const SizedBox(height: 16),
                      _CodeDisplay(
                        code: issued,
                        expiresLabel: 'teen.pending.code_expires'
                            .tr(namedArgs: {'when': _when(issued.expiresAt)}),
                        onCopy: () => _copy(issued),
                        onShare: () => _share(issued),
                      ),
                    ] else if (fromServer?.openLinkCode != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'teen.pending.code_open_existing'.tr(namedArgs: {
                          'when': _when(fromServer!.openLinkCode!.expiresAt),
                        }),
                        style: textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SacButton.primary(
                      text: issued == null &&
                              fromServer?.openLinkCode == null &&
                              guardians.isEmpty
                          ? 'teen.pending.code_generate'.tr()
                          : 'teen.pending.code_regenerate'.tr(),
                      icon: HugeIcons.strokeRoundedKey01,
                      isLoading: generating,
                      onPressed: generating ? null : _generate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'teen.pending.guardians_title'.tr()),
              const SizedBox(height: 8),
              if (guardians.isEmpty)
                SacCard(
                  child: Text(
                    'teen.pending.no_guardian'.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                )
              else ...[
                for (final guardian in guardians)
                  _GuardianTile(
                    guardian: guardian,
                    busy: _busy,
                    onRemove: () => _remove(guardian),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'teen.pending.guardian_pending_hint'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (supervisionAsync.hasError && fromServer == null) ...[
                const SizedBox(height: 12),
                _LoadError(
                  message: teenErrorMessage(supervisionAsync.error),
                  onRetry: () => ref.invalidate(supervisionStatusProvider),
                ),
              ],
              const SizedBox(height: 24),
              _SectionLabel(label: 'teen.pending.actions_title'.tr()),
              const SizedBox(height: 4),
              Text(
                'teen.pending.actions_hint'.tr(),
                style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              SacButton.outline(
                text: 'teen.pending.edit_profile'.tr(),
                icon: HugeIcons.strokeRoundedUserEdit01,
                onPressed: () => Navigator.push(
                  context,
                  SacSharedAxisRoute(builder: (_) => const EditProfileView()),
                ),
              ),
              const SizedBox(height: 12),
              SacButton.outline(
                text: 'teen.pending.change_password'.tr(),
                icon: HugeIcons.strokeRoundedLockPassword,
                onPressed: () => runChangePasswordFlow(context, ref),
              ),
              const SizedBox(height: 24),
              SacButton.ghost(
                text: 'legal_gate.sign_out'.tr(),
                icon: HugeIcons.strokeRoundedLogout02,
                textColor: AppColors.error,
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.sac.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
    );
  }
}

/// Cuenta atrás de los 90 días. El texto cambia con el plazo; los últimos días
/// se marcan como urgentes.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.daysLeft});

  final int daysLeft;

  static const int urgentDays = 14;

  @override
  Widget build(BuildContext context) {
    final urgent = daysLeft <= urgentDays;
    final message = switch (daysLeft) {
      0 => 'teen.pending.countdown_today'.tr(),
      1 => 'teen.pending.countdown_one'.tr(),
      _ => 'teen.pending.countdown'.tr(namedArgs: {'days': '$daysLeft'}),
    };
    return SacCard(
      key: const ValueKey('teen_pending_countdown'),
      backgroundColor: urgent ? AppColors.errorLight : null,
      borderColor: urgent ? AppColors.error.withValues(alpha: 0.3) : null,
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedClock01,
            size: 22,
            color: urgent ? AppColors.errorDark : SacAccent.of(context).color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: urgent ? AppColors.errorDark : context.sac.text,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({
    required this.code,
    required this.expiresLabel,
    required this.onCopy,
    required this.onShare,
  });

  final TeenLinkCode code;
  final String expiresLabel;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      key: const ValueKey('teen_pending_code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          code.code,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: c.text,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          expiresLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.textSecondary,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SacButton.outline(
                text: 'teen.pending.code_copy'.tr(),
                icon: HugeIcons.strokeRoundedCopy01,
                onPressed: onCopy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SacButton.outline(
                text: 'teen.pending.code_share'.tr(),
                icon: HugeIcons.strokeRoundedShare08,
                onPressed: onShare,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GuardianTile extends StatelessWidget {
  const _GuardianTile({
    required this.guardian,
    required this.busy,
    required this.onRemove,
  });

  final TeenGuardian guardian;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return SacCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guardian.displayName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    if (guardian.relationshipTypeName != null)
                      Text(
                        guardian.relationshipTypeName!,
                        style: textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              SacBadge.warning(
                label: guardian.verified
                    ? 'teen.pending.guardian_verified'.tr()
                    : 'teen.pending.guardian_pending'.tr(),
              ),
            ],
          ),
          if (guardian.canBeRemovedByTeen) ...[
            const SizedBox(height: 8),
            SacButton.ghost(
              text: 'teen.pending.guardian_remove'.tr(),
              icon: HugeIcons.strokeRoundedUserRemove01,
              textColor: AppColors.error,
              onPressed: busy ? null : onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.sac.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          SacButton.outline(text: 'common.retry'.tr(), onPressed: onRetry),
        ],
      ),
    );
  }
}
