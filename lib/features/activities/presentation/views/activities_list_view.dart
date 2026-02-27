import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../providers/activities_providers.dart';
import '../widgets/activity_card.dart';
import 'activity_detail_view.dart';

/// Vista de lista de actividades - Estilo "Scout Vibrante"
///
/// Chips horizontales de filtro por tipo, ActivityCards con
/// date badge indigo, SacBadge de tipo.
class ActivitiesListView extends ConsumerStatefulWidget {
  final int clubId;

  const ActivitiesListView({
    super.key,
    required this.clubId,
  });

  @override
  ConsumerState<ActivitiesListView> createState() =>
      _ActivitiesListViewState();
}

class _ActivitiesListViewState extends ConsumerState<ActivitiesListView> {
  String? _selectedFilter;

  static const _filters = [
    {'value': null, 'label': 'Todas'},
    {'value': 'meeting', 'label': 'Reuniones'},
    {'value': 'event', 'label': 'Eventos'},
    {'value': 'campout', 'label': 'Campamentos'},
    {'value': 'service', 'label': 'Servicios'},
  ];

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(clubActivitiesProvider(widget.clubId));

    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedCalendar01,
                      size: 24, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Actividades',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected =
                      _selectedFilter == filter['value'];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter['value'];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : c.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : c.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        filter['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : c.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Activities list
            Expanded(
              child: activitiesAsync.when(
                data: (activities) {
                  final filtered = _selectedFilter != null
                      ? activities
                          .where((a) => a.type == _selectedFilter)
                          .toList()
                      : activities;

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedCalendar04,
                              size: 56, color: c.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            _selectedFilter != null
                                ? 'No hay actividades de este tipo'
                                : 'No hay actividades disponibles',
                            style: TextStyle(
                              fontSize: 16,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(
                          clubActivitiesProvider(widget.clubId));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final activity = filtered[index];
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
                        Text(
                          'Error al cargar actividades',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        SacButton.primary(
                          text: 'Reintentar',
                          icon: HugeIcons.strokeRoundedRefresh,
                          onPressed: () {
                            ref.invalidate(
                                clubActivitiesProvider(widget.clubId));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
