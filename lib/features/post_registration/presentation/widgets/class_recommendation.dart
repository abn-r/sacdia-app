import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/club_selection_providers.dart';

/// Widget para mostrar recomendación de clase progresiva basada en edad
class ClassRecommendation extends ConsumerWidget {
  const ClassRecommendation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAge = ref.watch(userAgeProvider);
    final classesAsync = ref.watch(classesProvider);

    if (userAge == null) return const SizedBox.shrink();

    return classesAsync.when(
      data: (classes) {
        if (classes.isEmpty) return const SizedBox.shrink();

        // Buscar clase recomendada para la edad
        final recommendedClass = classes.firstWhere(
          (classModel) {
            if (classModel.minAge != null && classModel.maxAge != null) {
              return userAge >= classModel.minAge! &&
                  userAge <= classModel.maxAge!;
            }
            return false;
          },
          orElse: () => classes.first,
        );

        // Solo mostrar si encontramos una clase con rango de edad
        if (recommendedClass.minAge == null || recommendedClass.maxAge == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.school,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clase Recomendada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Para tu edad (${userAge} años), recomendamos la clase "${recommendedClass.name}"',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    if (recommendedClass.minAge != null &&
                        recommendedClass.maxAge != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Rango de edad: ${recommendedClass.minAge} - ${recommendedClass.maxAge} años',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
