import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../activities/domain/entities/activity.dart';
import '../../../activities/presentation/providers/activities_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classes/domain/entities/progressive_class.dart';
import '../../../classes/presentation/providers/classes_providers.dart';
import '../../../qr/presentation/providers/qr_member_token_provider.dart';
import '../../../virtual_card/presentation/widgets/virtual_card_qr_tile.dart';
import '../../domain/utils/next_activity.dart';

/// Inicio del teléfono vinculado: saludo, avance de clases, próxima actividad,
/// credencial (si el servidor la entrega) y «Desvincular este teléfono».
///
/// Nada de esto se puede editar desde aquí: no hay perfil, ni seguridad, ni
/// familia.
class DeviceHomeView extends ConsumerWidget {
  const DeviceHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final name = (user?.name ?? '').trim();
    final label = user?.principal?.device?.label;
    final classes = ref.watch(userClassesProvider);
    final clubId = user?.authorization?.activeGrant?.clubId;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: ListView(
          key: const ValueKey('device_home_list'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(
              name.isEmpty
                  ? 'device.home.greeting_anonymous'.tr()
                  : 'device.home.greeting'.tr(namedArgs: {'name': name}),
              key: const ValueKey('device_home_greeting'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'device.home.subtitle'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
            const SizedBox(height: 20),
            _ClassesSummary(classes: classes),
            const SizedBox(height: 16),
            if (clubId != null) _NextActivityCard(clubId: clubId),
            const SizedBox(height: 16),
            const _CredentialCard(),
            const SizedBox(height: 24),
            if (label != null && label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'device.home.this_phone'.tr(namedArgs: {'label': label}),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textTertiary,
                      ),
                ),
              ),
            SacButton.ghost(
              key: const ValueKey('device_unlink'),
              text: 'device.home.unlink'.tr(),
              icon: HugeIcons.strokeRoundedLinkBackward,
              textColor: AppColors.error,
              onPressed: () => _confirmUnlink(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// «Desvincular»: cierra la sesión (el servidor revoca el dispositivo con
  /// `device_logout`) y borra todo lo del menor de este teléfono.
  Future<void> _confirmUnlink(BuildContext context, WidgetRef ref) async {
    final ok = await SacDialog.show(
      context,
      title: 'device.home.unlink_title'.tr(),
      content: 'device.home.unlink_body'.tr(),
      confirmLabel: 'device.home.unlink_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = await ref.read(authNotifierProvider.notifier).signOut();
    if (!done) {
      SacSnackBar.showMessenger(
        messenger,
        'device.home.unlink_failed'.tr(),
        isError: true,
      );
    }
  }
}

class _ClassesSummary extends ConsumerWidget {
  const _ClassesSummary({required this.classes});

  final AsyncValue<List<ProgressiveClass>> classes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return SacCard(
      key: const ValueKey('device_home_classes'),
      onTap: () => context.go(RouteNames.deviceClasses),
      child: classes.when(
        loading: () => const Center(child: SacLoading()),
        error: (_, __) => Text(
          'device.classes.error'.tr(),
          style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        data: (list) {
          final enrolled = list.where((k) => k.enrollmentId != null).toList();
          if (enrolled.isEmpty) {
            return Text(
              'device.home.no_classes'.tr(),
              style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'device.home.classes_title'.tr(),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 12),
              for (final klass in enrolled.take(3)) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        klass.name,
                        style: textTheme.bodyMedium?.copyWith(color: c.text),
                      ),
                    ),
                    Text(
                      '${(klass.overallProgress ?? 0).clamp(0, 100)}%',
                      style: textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SacProgressBar(
                  progress:
                      ((klass.overallProgress ?? 0) / 100).clamp(0.0, 1.0),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NextActivityCard extends ConsumerWidget {
  const _NextActivityCard({required this.clubId});

  final int clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final activities = ref.watch(
      clubActivitiesProvider(ClubActivitiesParams(clubId: clubId)),
    );
    final list = activities.valueOrNull;
    final Activity? next =
        list == null ? null : nextUpcomingActivity(list, DateTime.now());
    return SacCard(
      key: const ValueKey('device_home_next_activity'),
      onTap: next == null
          ? () => context.go(RouteNames.deviceAgenda)
          : () => context.push(RouteNames.deviceActivityDetailPath(next.id)),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            size: 24,
            color: SacAccent.of(context).color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'device.home.next_activity'.tr(),
                  style: textTheme.labelMedium?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next?.name ?? 'device.home.no_activity'.tr(),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                if (next?.activityDate != null)
                  Text(
                    DateFormat.MMMEd(context.locale.toLanguageTag())
                        .format(next!.activityDate!),
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Credencial del miembro (`credential:read`). Si el servidor no la entrega
/// (sin permiso o sin red) la tarjeta desaparece: no hay reintento ni bucle.
class _CredentialCard extends ConsumerWidget {
  const _CredentialCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(qrMemberTokenProvider);
    return token.maybeWhen(
      data: (value) {
        final c = context.sac;
        return SacCard(
          key: const ValueKey('device_home_credential'),
          child: Column(
            children: [
              Text(
                'device.home.credential_title'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
              ),
              const SizedBox(height: 12),
              VirtualCardQrTile(data: value.token, maxSize: 180),
              const SizedBox(height: 8),
              Text(
                'device.home.credential_hint'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
            ],
          ),
        );
      },
      orElse: () =>
          const SizedBox.shrink(key: ValueKey('device_home_no_credential')),
    );
  }
}
