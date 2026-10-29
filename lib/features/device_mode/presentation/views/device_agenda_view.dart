import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../activities/domain/entities/activity.dart';
import '../../../activities/presentation/providers/activities_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Agenda del club del menor: fecha, título y lugar. Sin listas de asistentes
/// ni de otros menores (el servidor las quita del payload de un teléfono
/// vinculado y esta vista tampoco las muestra jamás).
class DeviceAgendaView extends ConsumerWidget {
  const DeviceAgendaView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final clubId = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull?.deviceClubId),
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'device.agenda.title'.tr(),
        automaticallyImplyLeading: false,
      ),
      // `/auth/me` solo trae el club de la asignación activa: el teléfono no
      // distingue «sin club» de «solicitud pendiente», así que el texto vale
      // para ambos casos.
      body: clubId == null
          ? SacEmptyState(
              key: const ValueKey('device_agenda_no_club'),
              title: 'device.agenda.no_club'.tr(),
              icon: HugeIcons.strokeRoundedCalendar01,
            )
          : _AgendaList(clubId: clubId),
    );
  }
}

class _AgendaList extends ConsumerWidget {
  const _AgendaList({required this.clubId});

  final int clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ClubActivitiesParams(clubId: clubId);
    final async = ref.watch(clubActivitiesProvider(params));
    return async.when(
      loading: () => const Center(child: SacLoading()),
      error: (_, __) => SacEmptyState(
        key: const ValueKey('device_agenda_error'),
        title: 'device.agenda.error'.tr(),
        icon: HugeIcons.strokeRoundedAlert02,
        actionLabel: 'common.retry'.tr(),
        actionVariant: SacButtonVariant.outline,
        onAction: () => ref.invalidate(clubActivitiesProvider(params)),
      ),
      data: (activities) {
        final upcoming = _upcoming(activities);
        if (upcoming.isEmpty) {
          return SacEmptyState(
            key: const ValueKey('device_agenda_empty'),
            title: 'device.agenda.empty'.tr(),
            icon: HugeIcons.strokeRoundedCalendar01,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clubActivitiesProvider(params));
            await ref.read(clubActivitiesProvider(params).future);
          },
          child: ListView.builder(
            key: const ValueKey('device_agenda_list'),
            padding: const EdgeInsets.all(16),
            itemCount: upcoming.length,
            itemBuilder: (context, index) =>
                _ActivityTile(activity: upcoming[index]),
          ),
        );
      },
    );
  }

  /// Hoy y lo que sigue, en orden. Lo pasado no se muestra.
  List<Activity> _upcoming(List<Activity> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = all.where((a) {
      final date = a.activityDate;
      if (!a.active || date == null) return false;
      return !DateTime(date.year, date.month, date.day).isBefore(today);
    }).toList()
      ..sort((a, b) => a.activityDate!.compareTo(b.activityDate!));
    return list;
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final date = activity.activityDate;
    return SacCard(
      key: ValueKey('device_activity_${activity.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () =>
          context.push(RouteNames.deviceActivityDetailPath(activity.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (date != null)
            Text(
              DateFormat.MMMEd(context.locale.toLanguageTag()).format(date),
              style: textTheme.labelMedium?.copyWith(color: c.textSecondary),
            ),
          const SizedBox(height: 2),
          Text(
            activity.name,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          if (activity.activityPlace.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              activity.activityPlace,
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
