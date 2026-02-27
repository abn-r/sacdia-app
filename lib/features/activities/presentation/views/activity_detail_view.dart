import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/activities_providers.dart';
import '../widgets/attendance_button.dart';
import '../widgets/activity_info_row.dart';

/// Vista de detalle de actividad - Estilo "Scout Vibrante"
///
/// Header con gradiente por tipo, info rows con iconBox,
/// AttendanceButton, floating SnackBars.
class ActivityDetailView extends ConsumerStatefulWidget {
  final int activityId;

  const ActivityDetailView({
    super.key,
    required this.activityId,
  });

  @override
  ConsumerState<ActivityDetailView> createState() =>
      _ActivityDetailViewState();
}

class _ActivityDetailViewState extends ConsumerState<ActivityDetailView> {
  bool _hasRegistered = false;

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return AppColors.primary;
      case 'event':
        return AppColors.accent;
      case 'campout':
        return AppColors.secondary;
      case 'service':
        return const Color(0xFF0EA5E9);
      default:
        return AppColors.primary;
    }
  }

  dynamic _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return HugeIcons.strokeRoundedUserGroup;
      case 'event':
        return HugeIcons.strokeRoundedCalendar01;
      case 'campout':
        return HugeIcons.strokeRoundedCampfire;
      case 'service':
        return HugeIcons.strokeRoundedCharity;
      default:
        return HugeIcons.strokeRoundedCalendarAdd01;
    }
  }

  String _getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return 'Reunión';
      case 'event':
        return 'Evento';
      case 'campout':
        return 'Campamento';
      case 'service':
        return 'Servicio';
      default:
        return 'Actividad';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));
    final authState = ref.watch(authNotifierProvider);
    final attendanceState = ref.watch(attendanceNotifierProvider);

    return Scaffold(
      backgroundColor: context.sac.background,
      body: activityAsync.when(
        data: (activity) {
          final typeColor = _getTypeColor(activity.type);

          return CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: typeColor,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          typeColor,
                          typeColor.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Icon(
                            _getTypeIcon(activity.type),
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              activity.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getTypeText(activity.type),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ActivityInfoRow(
                        icon: HugeIcons.strokeRoundedCalendar01,
                        label: 'Fecha',
                        value: DateFormat('EEEE, dd MMMM yyyy', 'es')
                            .format(activity.date),
                      ),
                      ActivityInfoRow(
                        icon: HugeIcons.strokeRoundedClock01,
                        label: 'Hora',
                        value: DateFormat('HH:mm').format(activity.date),
                      ),
                      if (activity.location != null)
                        ActivityInfoRow(
                          icon: HugeIcons.strokeRoundedLocation01,
                          label: 'Lugar',
                          value: activity.location!,
                        ),
                      if (activity.description != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle,
                                size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Descripción',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          activity.description!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: context.sac.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Attendance button
                      AttendanceButton(
                        isAttending: _hasRegistered ||
                            (attendanceState.value != null &&
                                attendanceState.value! > 0),
                        isLoading: attendanceState.isLoading,
                        onPressed: () async {
                          final userId = authState.value?.id;
                          if (userId == null) return;

                          await ref
                              .read(attendanceNotifierProvider.notifier)
                              .register(widget.activityId, userId);

                          if (!mounted) return;
                          if (attendanceState.hasError) return;

                          setState(() {
                            _hasRegistered = true;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Asistencia registrada exitosamente'),
                              backgroundColor: AppColors.secondary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: SacLoading()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                    size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Error al cargar detalle',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                SacButton.primary(
                  text: 'Reintentar',
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: () {
                    ref.invalidate(
                        activityDetailProvider(widget.activityId));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
