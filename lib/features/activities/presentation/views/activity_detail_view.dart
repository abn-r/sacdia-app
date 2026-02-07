import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/activities_providers.dart';
import '../widgets/attendance_button.dart';
import '../widgets/activity_info_row.dart';

/// Vista de detalle de una actividad
class ActivityDetailView extends ConsumerStatefulWidget {
  final int activityId;

  const ActivityDetailView({
    Key? key,
    required this.activityId,
  }) : super(key: key);

  @override
  ConsumerState<ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends ConsumerState<ActivityDetailView> {
  bool _hasRegistered = false;

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));
    final authState = ref.watch(authNotifierProvider);
    final attendanceState = ref.watch(attendanceNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Actividad'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: activityAsync.when(
        data: (activity) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con tipo de actividad
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  color: _getTypeColor(activity.type).withOpacity(0.1),
                  child: Column(
                    children: [
                      Icon(
                        _getTypeIcon(activity.type),
                        size: 60,
                        color: _getTypeColor(activity.type),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        activity.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getTypeColor(activity.type),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getTypeText(activity.type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Información de la actividad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ActivityInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Fecha',
                        value: DateFormat('EEEE, dd MMMM yyyy', 'es').format(activity.date),
                      ),
                      ActivityInfoRow(
                        icon: Icons.access_time,
                        label: 'Hora',
                        value: DateFormat('HH:mm').format(activity.date),
                      ),
                      if (activity.location != null)
                        ActivityInfoRow(
                          icon: Icons.location_on,
                          label: 'Lugar',
                          value: activity.location!,
                        ),
                      if (activity.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Descripción',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activity.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Botón de asistencia
                      AttendanceButton(
                        isAttending: _hasRegistered ||
                            (attendanceState.value != null &&
                                attendanceState.value!.activityId == widget.activityId),
                        isLoading: attendanceState.isLoading,
                        onPressed: () async {
                          final userId = authState.value?.id;
                          if (userId == null) return;

                          await ref
                              .read(attendanceNotifierProvider.notifier)
                              .register(widget.activityId, userId, true);

                          if (mounted && !attendanceState.hasError) {
                            setState(() {
                              _hasRegistered = true;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Asistencia registrada exitosamente'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar detalle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: AppColors.lightTextSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(activityDetailProvider(widget.activityId));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Obtiene el color según el tipo de actividad
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return AppColors.info;
      case 'event':
        return AppColors.primaryBlue;
      case 'campout':
        return AppColors.sacGreen;
      case 'service':
        return AppColors.secondaryTeal;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  /// Obtiene el icono según el tipo de actividad
  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.groups;
      case 'event':
        return Icons.event;
      case 'campout':
        return Icons.forest;
      case 'service':
        return Icons.volunteer_activism;
      default:
        return Icons.event_available;
    }
  }

  /// Obtiene el texto según el tipo de actividad
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
}
