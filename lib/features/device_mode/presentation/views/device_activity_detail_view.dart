import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../activities/presentation/providers/activities_providers.dart';

/// Detalle de una actividad: nombre, fecha, hora, lugar y descripción. NUNCA
/// asistentes ni otros menores (privacidad: el teléfono no ve a nadie más).
class DeviceActivityDetailView extends ConsumerWidget {
  const DeviceActivityDetailView({super.key, required this.activityId});

  final int activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(activityDetailProvider(activityId));

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(title: 'device.agenda.detail_title'.tr()),
      body: async.when(
        loading: () => const Center(child: SacLoading()),
        error: (_, __) => SacEmptyState(
          key: const ValueKey('device_activity_error'),
          title: 'device.agenda.detail_error'.tr(),
          icon: HugeIcons.strokeRoundedAlert02,
          actionLabel: 'common.retry'.tr(),
          actionVariant: SacButtonVariant.outline,
          onAction: () => ref.invalidate(activityDetailProvider(activityId)),
        ),
        data: (activity) => ListView(
          key: const ValueKey('device_activity_detail'),
          padding: const EdgeInsets.all(16),
          children: [
            SacCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.name,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activity.activityDate != null)
                    _Row(
                      icon: HugeIcons.strokeRoundedCalendar01,
                      text: [
                        DateFormat.yMMMMEEEEd(context.locale.toLanguageTag())
                            .format(activity.activityDate!),
                        if ((activity.activityTime ?? '').trim().isNotEmpty)
                          activity.activityTime!,
                      ].join(' · '),
                    ),
                  if (activity.activityPlace.trim().isNotEmpty)
                    _Row(
                      icon: HugeIcons.strokeRoundedLocation01,
                      text: activity.activityPlace,
                    ),
                  if ((activity.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      activity.description!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text});

  final List<List<dynamic>> icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 18, color: c.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.text,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
