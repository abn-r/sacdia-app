import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../providers/honors_providers.dart';
import '../widgets/honor_category_card.dart';
import '../widgets/honor_card.dart';
import 'honor_detail_view.dart';

/// Vista de catálogo de especialidades - Estilo "Scout Vibrante"
///
/// Grid responsivo de categorías: 2 columnas en teléfonos, 3-4 en tablets.
/// Al seleccionar muestra lista filtrada con chips scrollables.
/// Sin AppBar (tab).
class HonorsCatalogView extends ConsumerStatefulWidget {
  const HonorsCatalogView({super.key});

  @override
  ConsumerState<HonorsCatalogView> createState() => _HonorsCatalogViewState();
}

class _HonorsCatalogViewState extends ConsumerState<HonorsCatalogView> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(honorCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: categoriesAsync.when(
          data: (categories) {
            if (_selectedCategoryId == null) {
              return _buildCategoriesGrid(categories);
            } else {
              return _buildHonorsList(_selectedCategoryId!);
            }
          },
          loading: () => const Center(child: SacLoading()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      size: 56,
                      color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar categorías',
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
                      ref.invalidate(honorCategoriesProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(List<dynamic> categories) {
    final hPad = Responsive.horizontalPadding(context);

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
            child: Row(
              children: [
                HugeIcon(
                    icon: HugeIcons.strokeRoundedAward01,
                    size: 24,
                    color: AppColors.accent),
                const SizedBox(width: 10),
                Text(
                  'Especialidades',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        // Responsive grid: SliverGridDelegateWithMaxCrossAxisExtent gives
        // 2 columns on phones (~180px each) and 3-4 on tablets automatically.
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: Responsive.honorGridMaxCrossAxisExtent,
              childAspectRatio: 1.15,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
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
              childCount: categories.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildHonorsList(int categoryId) {
    final honorsAsync = ref.watch(honorsByCategoryProvider(categoryId));

    return Column(
      children: [
        // Back bar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoryId = null;
                  });
                },
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01, size: 24),
                color: AppColors.primary,
              ),
              Text(
                'Categoría',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        // Honors list
        Expanded(
          child: honorsAsync.when(
            data: (honors) {
              if (honors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                          icon: HugeIcons.strokeRoundedAward01,
                          size: 56,
                          color: AppColors.lightTextTertiary),
                      const SizedBox(height: 12),
                      Text(
                        'No hay especialidades en esta categoría',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final hPad = Responsive.horizontalPadding(context);
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
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
            loading: () => const Center(child: SacLoading()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        size: 56,
                        color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error al cargar especialidades',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 24),
                    SacButton.primary(
                      text: 'Reintentar',
                      icon: HugeIcons.strokeRoundedRefresh,
                      onPressed: () {
                        ref.invalidate(honorsByCategoryProvider(categoryId));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
