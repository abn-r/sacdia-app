import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/club_instance_model.dart';
import '../providers/club_selection_providers.dart';

/// Widget para mostrar el selector de tipo de club con recomendación por edad
class ClubTypeSelector extends ConsumerWidget {
  const ClubTypeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubInstancesAsync = ref.watch(clubInstancesProvider);
    final selectedInstanceId = ref.watch(selectedClubInstanceProvider);
    final userAge = ref.watch(userAgeProvider);

    return clubInstancesAsync.when(
      data: (instances) {
        if (instances.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo de Club',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),

            // Mensaje de recomendación por edad
            if (userAge != null) _buildAgeRecommendation(context, userAge),

            const SizedBox(height: 12),

            // Opciones de tipo de club
            ...instances.map((instance) {
              final isSelected = selectedInstanceId == instance.id;
              final isRecommended = _isRecommendedForAge(instance, userAge);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    ref.read(selectedClubInstanceProvider.notifier).state = instance.id;
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            instance.clubTypeName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Recomendado',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Error al cargar tipos de club: $error',
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }

  Widget _buildAgeRecommendation(BuildContext context, int age) {
    String recommendation = '';
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;

    if (age >= 4 && age <= 9) {
      recommendation = 'Para tu edad (${age} años), recomendamos el club de Aventureros.';
      icon = Icons.child_care;
      color = Colors.orange;
    } else if (age >= 10 && age <= 15) {
      recommendation = 'Para tu edad (${age} años), recomendamos el club de Conquistadores.';
      icon = Icons.hiking;
      color = Colors.blue;
    } else if (age >= 16) {
      recommendation = 'Para tu edad (${age} años), recomendamos el club de Guías Mayores.';
      icon = Icons.groups;
      color = Colors.green;
    }

    if (recommendation.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recommendation,
              style: TextStyle(
                fontSize: 13,
                color: color.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isRecommendedForAge(ClubInstanceModel instance, int? age) {
    if (age == null) return false;

    final typeName = instance.clubTypeName.toLowerCase();

    if (age >= 4 && age <= 9) {
      return typeName.contains('aventurero');
    } else if (age >= 10 && age <= 15) {
      return typeName.contains('conquistador');
    } else if (age >= 16) {
      return typeName.contains('guía');
    }

    return false;
  }
}
