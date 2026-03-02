import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/usecases/get_honors.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';

/// Category color map – same as in profile_honors_section.dart
const Map<String, Color> _categoryColors = {
  'ADRA': AppColors.catAdra,
  'Agropecuarias': AppColors.catagropecuarias,
  'Ciencias de la Salud': AppColors.catCienciasSalud,
  'Domésticas': AppColors.catDomesticas,
  'Habilidades Manuales': AppColors.catHabilidadesManuales,
  'Misioneras': AppColors.catMisioneras,
  'Naturaleza': AppColors.catNaturaleza,
  'Profesionales': AppColors.catProfesionales,
  'Recreativas': AppColors.catRecreativas,
};

const Map<String, IconData> _categoryIcons = {
  'ADRA': Icons.volunteer_activism,
  'Agropecuarias': Icons.agriculture,
  'Ciencias de la Salud': Icons.medical_services,
  'Domésticas': Icons.home,
  'Habilidades Manuales': Icons.handyman,
  'Misioneras': Icons.public,
  'Naturaleza': Icons.forest,
  'Profesionales': Icons.work,
  'Recreativas': Icons.sports_handball,
};

/// Pantalla para agregar una nueva especialidad al perfil del usuario.
///
/// Muestra todas las categorías con sus especialidades en ExpansionTiles,
/// con un buscador de texto para filtrar. Al seleccionar una especialidad
/// navega al detalle donde el usuario puede inscribirse.
class AddHonorView extends ConsumerStatefulWidget {
  const AddHonorView({super.key});

  @override
  ConsumerState<AddHonorView> createState() => _AddHonorViewState();
}

class _AddHonorViewState extends ConsumerState<AddHonorView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(honorCategoriesProvider);
    final allHonorsAsync =
        ref.watch(honorsProvider(const GetHonorsParams()));

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ESPECIALIDADES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar especialidad...',
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 20,
                    color: context.sac.textTertiary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 18,
                            color: context.sac.textTertiary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.sac.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.sac.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  filled: true,
                  fillColor: context.sac.surface,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),

            // Categories list
            Expanded(
              child: categoriesAsync.when(
                loading: () => const Center(child: SacLoading()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar categorías',
                        style: TextStyle(color: context.sac.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(honorCategoriesProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (categories) => allHonorsAsync.when(
                  loading: () => const Center(child: SacLoading()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (allHonors) {
                    // Group honors by category
                    final Map<int, List<Honor>> byCategory = {};
                    for (final h in allHonors) {
                      byCategory
                          .putIfAbsent(h.categoryId, () => [])
                          .add(h);
                    }

                    // Apply search filter
                    final filteredCategories = categories.map((cat) {
                      final honors = byCategory[cat.id] ?? [];
                      if (_searchQuery.isEmpty) {
                        return _FilteredCategory(
                            category: cat, honors: honors);
                      }
                      final filtered = honors
                          .where((h) => h.name
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                          .toList();
                      return _FilteredCategory(
                          category: cat, honors: filtered);
                    }).where((fc) => fc.honors.isNotEmpty).toList();

                    if (filteredCategories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              size: 48,
                              color: context.sac.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron especialidades',
                              style: TextStyle(
                                fontSize: 16,
                                color: context.sac.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        final fc = filteredCategories[index];
                        return _CategoryExpansionTile(
                          category: fc.category,
                          honors: fc.honors,
                          initiallyExpanded: _searchQuery.isNotEmpty,
                          onHonorSelected: (honor) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HonorDetailView(
                                  honorId: honor.id,
                                ),
                              ),
                            ).then((result) {
                              if (result == true && context.mounted) {
                                Navigator.pop(context, true);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredCategory {
  final HonorCategory category;
  final List<Honor> honors;

  _FilteredCategory({required this.category, required this.honors});
}

class _CategoryExpansionTile extends StatelessWidget {
  final HonorCategory category;
  final List<Honor> honors;
  final bool initiallyExpanded;
  final void Function(Honor) onHonorSelected;

  const _CategoryExpansionTile({
    required this.category,
    required this.honors,
    required this.initiallyExpanded,
    required this.onHonorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor =
        _categoryColors[category.name] ?? AppColors.sacBlack;
    final categoryIcon = _categoryIcons[category.name] ?? Icons.star;
    final isNature = category.name == 'Naturaleza' ||
        category.name == 'Estudio de la naturaleza';

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: isNature
            ? AppColors.sacBlack
            : categoryColor,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isNature
                  ? AppColors.sacBlack.withAlpha(80)
                  : categoryColor.withAlpha(80),
              width: 1.5,
            ),
            bottom: BorderSide(
              color: isNature
                  ? AppColors.sacBlack.withAlpha(80)
                  : categoryColor.withAlpha(80),
              width: 1.5,
            ),
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          collapsedBackgroundColor: categoryColor.withAlpha(15),
          backgroundColor: categoryColor.withAlpha(8),
          iconColor: isNature ? AppColors.sacBlack : categoryColor,
          collapsedIconColor: isNature ? AppColors.sacBlack : categoryColor,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  categoryIcon,
                  color: isNature ? AppColors.sacBlack : Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: isNature ? AppColors.sacBlack : categoryColor,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isNature
                        ? AppColors.sacBlack.withAlpha(60)
                        : categoryColor.withAlpha(60),
                  ),
                ),
                child: Text(
                  '${honors.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isNature ? AppColors.sacBlack : categoryColor,
                  ),
                ),
              ),
            ],
          ),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.78,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: honors.length,
              itemBuilder: (context, index) {
                final honor = honors[index];
                return _HonorSelectItem(
                  honor: honor,
                  categoryColor: categoryColor,
                  onTap: () => onHonorSelected(honor),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HonorSelectItem extends StatelessWidget {
  final Honor honor;
  final Color categoryColor;
  final VoidCallback onTap;

  const _HonorSelectItem({
    required this.honor,
    required this.categoryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = honor.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join('');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: honor.imageUrl != null && honor.imageUrl!.isNotEmpty
                  ? Image.network(
                      honor.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _InitialsBox(
                        initials: initials,
                        categoryColor: categoryColor,
                      ),
                    )
                  : _InitialsBox(
                      initials: initials,
                      categoryColor: categoryColor,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            honor.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.sac.text,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InitialsBox extends StatelessWidget {
  final String initials;
  final Color categoryColor;

  const _InitialsBox({
    required this.initials,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: categoryColor.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: categoryColor.withAlpha(50), width: 1),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: categoryColor,
          ),
        ),
      ),
    );
  }
}
