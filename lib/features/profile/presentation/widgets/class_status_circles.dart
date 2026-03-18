import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';

/// Displays Conquistador progressive class status circles and the
/// Guia Mayor SVG badge.  Adapted from the reference StatusCirclesSection /
/// StatusCircleWidget but using Riverpod and the current design system.
class ClassStatusCircles extends ConsumerWidget {
  const ClassStatusCircles({super.key});

  // Map class names to their brand colours (same palette as AppColors)
  static const Map<String, Color> _classColors = {
    'Amigo': AppColors.colorAmigo,
    'Compañero': AppColors.colorCompanero,
    'Explorador': AppColors.colorExplorador,
    'Orientador': AppColors.colorOrientador,
    'Viajero': AppColors.colorViajero,
    'Guía': AppColors.colorGuia,
  };

  static const List<String> _classOrder = [
    'Amigo',
    'Compañero',
    'Explorador',
    'Orientador',
    'Viajero',
    'Guía',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(userClassesProvider);

    return classesAsync.when(
      data: (classes) => _buildContent(context, classes),
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(BuildContext context, List<ProgressiveClass> classes) {
    final classNames = classes.map((c) => c.name).toSet();
    final isGuiaMayor = classNames.contains('Guía Mayor');

    return Column(
      children: [
        // Guia Mayor SVG badge (centered above the row)
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isGuiaMayor
                      ? 'Investido de la clase de Guías Mayores'
                      : 'Sin investidura de Guías Mayores',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGuiaMayor
                  ? AppColors.colorGuiaMayor
                  : context.sac.border.withAlpha(60),
            ),
            child: Center(
              child: Image.asset(
                'assets/img/logos-clases/G1.png',
                width: 44,
                height: 44,
                color: Colors.white,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shield,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Six Conquistador class circles
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _classOrder.map((className) {
              final isActive = classNames.contains(className);
              final color = _classColors[className] ?? AppColors.primary;
              return _ClassCircle(
                label: className,
                isActive: isActive,
                activeColor: color,
                imagePath: 'assets/img/logos-clases/C3_NEGRO.png',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isActive
                            ? 'Clase $className completada'
                            : 'Clase $className pendiente',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Single class status circle with an asset image inside.
class _ClassCircle extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final String imagePath;
  final VoidCallback? onTap;

  const _ClassCircle({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.imagePath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = 46.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor
                  : context.sac.border.withAlpha(60),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                color: Colors.white,
                width: size * 0.6,
                height: size * 0.6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? activeColor
                  : context.sac.textTertiary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
