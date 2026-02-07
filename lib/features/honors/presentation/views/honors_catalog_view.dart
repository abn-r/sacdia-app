import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/honors_providers.dart';
import '../widgets/honor_category_card.dart';
import '../widgets/honor_card.dart';
import 'honor_detail_view.dart';

/// Vista de catálogo de especialidades
class HonorsCatalogView extends ConsumerStatefulWidget {
  const HonorsCatalogView({Key? key}) : super(key: key);

  @override
  ConsumerState<HonorsCatalogView> createState() => _HonorsCatalogViewState();
}

class _HonorsCatalogViewState extends ConsumerState<HonorsCatalogView> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(honorCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Especialidades'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (_selectedCategoryId == null) {
            // Mostrar grid de categorías
            return _buildCategoriesGrid(categories);
          } else {
            // Mostrar lista de especialidades por categoría
            return _buildHonorsList(_selectedCategoryId!);
          }
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
                'Error al cargar categorías',
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
                  ref.invalidate(honorCategoriesProvider);
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

  /// Construye el grid de categorías
  Widget _buildCategoriesGrid(categories) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return HonorCategoryCard(
          category: category,
          onTap: () {
            setState(() {
              _selectedCategoryId = category.id;
            });
          },
        );
      },
    );
  }

  /// Construye la lista de especialidades por categoría
  Widget _buildHonorsList(int categoryId) {
    final honorsAsync = ref.watch(honorsByCategoryProvider(categoryId));

    return Column(
      children: [
        // Botón para volver a categorías
        Container(
          padding: const EdgeInsets.all(8),
          child: ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Volver a categorías'),
            onTap: () {
              setState(() {
                _selectedCategoryId = null;
              });
            },
          ),
        ),
        const Divider(),
        // Lista de especialidades
        Expanded(
          child: honorsAsync.when(
            data: (honors) {
              if (honors.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        size: 80,
                        color: AppColors.lightTextSecondary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay especialidades en esta categoría',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: honors.length,
                itemBuilder: (context, index) {
                  final honor = honors[index];
                  return HonorCard(
                    honor: honor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HonorDetailView(
                            honorId: honor.id,
                          ),
                        ),
                      );
                    },
                  );
                },
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
                    'Error al cargar especialidades',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(honorsByCategoryProvider(categoryId));
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
