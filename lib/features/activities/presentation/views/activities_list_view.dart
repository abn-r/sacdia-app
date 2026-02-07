import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/activities_providers.dart';
import '../widgets/activity_card.dart';
import 'activity_detail_view.dart';

/// Vista de lista de actividades del club
class ActivitiesListView extends ConsumerStatefulWidget {
  final int clubId;

  const ActivitiesListView({
    Key? key,
    required this.clubId,
  }) : super(key: key);

  @override
  ConsumerState<ActivitiesListView> createState() => _ActivitiesListViewState();
}

class _ActivitiesListViewState extends ConsumerState<ActivitiesListView> {
  String? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(clubActivitiesProvider(widget.clubId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividades del Club'),
        backgroundColor: AppColors.primaryBlue,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value == 'all' ? null : value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Todas'),
              ),
              const PopupMenuItem(
                value: 'meeting',
                child: Text('Reuniones'),
              ),
              const PopupMenuItem(
                value: 'event',
                child: Text('Eventos'),
              ),
              const PopupMenuItem(
                value: 'campout',
                child: Text('Campamentos'),
              ),
              const PopupMenuItem(
                value: 'service',
                child: Text('Servicios'),
              ),
            ],
          ),
        ],
      ),
      body: activitiesAsync.when(
        data: (activities) {
          // Filtrar actividades si es necesario
          final filteredActivities = _selectedFilter != null
              ? activities.where((a) => a.type == _selectedFilter).toList()
              : activities;

          if (filteredActivities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.event_busy,
                    size: 80,
                    color: AppColors.lightTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter != null
                        ? 'No hay actividades de este tipo'
                        : 'No hay actividades disponibles',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(clubActivitiesProvider(widget.clubId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filteredActivities.length,
              itemBuilder: (context, index) {
                final activity = filteredActivities[index];
                return ActivityCard(
                  activity: activity,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActivityDetailView(
                          activityId: activity.id,
                        ),
                      ),
                    );
                  },
                );
              },
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
                'Error al cargar actividades',
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
                  ref.invalidate(clubActivitiesProvider(widget.clubId));
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
}
