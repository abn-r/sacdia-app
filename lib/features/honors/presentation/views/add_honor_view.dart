import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_group.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/views/honor_detail_view.dart';

/// Colores por nombre de categoría
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

Color _colorForCategory(String name) {
  final color = _categoryColors[name];
  if (color == null) return AppColors.sacBlack;
  // Naturaleza con negro para legibilidad
  if (name == 'Naturaleza' || name == 'Estudio de la naturaleza') {
    return AppColors.sacBlack;
  }
  return color;
}

/// Pantalla para agregar una nueva especialidad al perfil del usuario.
///
/// Muestra todas las categorías con sus especialidades en secciones planas
/// (sin acordeón), con buscador pill y chips de categoría. Al seleccionar
/// una especialidad navega al detalle donde el usuario puede inscribirse.
class AddHonorView extends ConsumerStatefulWidget {
  const AddHonorView({super.key});

  @override
  ConsumerState<AddHonorView> createState() => _AddHonorViewState();
}

class _AddHonorViewState extends ConsumerState<AddHonorView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  String? _selectedCategory; // null = "Todas"
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(honorsGroupedByCategoryProvider);

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: _buildAppBar(groupsAsync),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ─────────────────────────────────────────
            _buildSearchBar(context),

            // ── Category filter chips ──────────────────────────────
            groupsAsync.maybeWhen(
              data: (groups) => _buildCategoryChips(context, groups),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),

            // ── Content ────────────────────────────────────────────
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(child: SacLoading()),
                error: (e, _) => _buildErrorState(context),
                data: (groups) => _buildGroupList(context, groups),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(AsyncValue<List<HonorGroup>> groupsAsync) {
    final totalCount = groupsAsync.maybeWhen(
      data: (groups) => groups.fold<int>(0, (sum, g) => sum + g.honors.length),
      orElse: () => null,
    );

    final c = context.sac;

    return AppBar(
      backgroundColor: c.background,
      foregroundColor: c.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowLeft01,
          color: c.text,
          size: 22,
        ),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Volver',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ESPECIALIDADES',
            style: TextStyle(
              color: c.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (totalCount != null)
            Text(
              '$totalCount especialidades disponibles',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'Buscar especialidad...',
          prefixIcon: Center(
            widthFactor: 1,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 18,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: context.sac.surfaceVariant,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  // ── Category chips ────────────────────────────────────────────────────────

  Widget _buildCategoryChips(BuildContext context, List<HonorGroup> groups) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _CategoryChip(
            label: 'Todas',
            color: AppColors.primary,
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          ...groups.map((group) {
            final color = _colorForCategory(group.category.name);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: group.category.name,
                color: color,
                isSelected: _selectedCategory == group.category.name,
                onTap: () => setState(() {
                  _selectedCategory = _selectedCategory == group.category.name
                      ? null
                      : group.category.name;
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Group list ────────────────────────────────────────────────────────────

  Widget _buildGroupList(BuildContext context, List<HonorGroup> groups) {
    // Aplicar filtros
    final filtered = groups
        .where((g) {
          // Filtro por chip de categoría
          if (_selectedCategory != null &&
              g.category.name != _selectedCategory) {
            return false;
          }
          return true;
        })
        .map((g) {
          List<Honor> honors = g.honors;
          // Filtro por texto de búsqueda
          if (_searchQuery.isNotEmpty) {
            honors = honors
                .where((h) =>
                    h.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();
          }
          return _FilteredGroup(group: g, honors: honors);
        })
        .where((fg) => fg.honors.isNotEmpty)
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final fg = filtered[index];
        final categoryColor = _colorForCategory(fg.group.category.name);
        final categoryIcon =
            _categoryIcons[fg.group.category.name] ?? Icons.star;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.sac.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Contenido principal con borde uniforme
                Container(
                  decoration: BoxDecoration(
                    color: context.sac.surface,
                    border: Border.all(color: context.sac.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Category header ─────────────────────────────
                      _CategorySectionHeader(
                        name: fg.group.category.name,
                        icon: categoryIcon,
                        color: categoryColor,
                        count: fg.honors.length,
                      ),
                      // ── Subtle divider ──────────────────────────────
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: categoryColor.withAlpha(30),
                        indent: 16,
                        endIndent: 16,
                      ),
                      // ── Grid de honores ─────────────────────────────
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: fg.honors.length,
                        itemBuilder: (context, hIndex) {
                          final honor = fg.honors[hIndex];
                          return _HonorSelectItem(
                            honor: honor,
                            categoryColor: categoryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HonorDetailView(
                                    honorId: honor.id,
                                    initialHonor: honor,
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
                      ),
                    ],
                  ),
                ),
                // Barra de acento lateral posicionada absolutamente
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: categoryColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final hasFilter = _searchQuery.isNotEmpty || _selectedCategory != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: 36,
                  color: AppColors.primary.withAlpha(180),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin resultados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.sac.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'No hay especialidades que coincidan con tu búsqueda.'
                  : 'No hay especialidades disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.sac.textSecondary,
                height: 1.4,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Limpiar filtros'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.sac.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.sac.surface,
                    border: Border.all(color: context.sac.border, width: 1),
                  ),
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
                        'Error al cargar especialidades',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.sac.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Revisa tu conexión e intenta de nuevo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.sac.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              ref.invalidate(honorsGroupedByCategoryProvider),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reintentar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: AppColors.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supporting data class ─────────────────────────────────────────────────────

class _FilteredGroup {
  final HonorGroup group;
  final List<Honor> honors;

  _FilteredGroup({required this.group, required this.honors});
}

// ── Category section header ───────────────────────────────────────────────────

class _CategorySectionHeader extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final int count;

  const _CategorySectionHeader({
    required this.name,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Category icon in rounded container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color == AppColors.sacBlack ? Colors.white : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Category name
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ),
          // Count badge pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(60), width: 1),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withAlpha(60),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ── Honor select item ─────────────────────────────────────────────────────────

class _HonorSelectItem extends StatefulWidget {
  final Honor honor;
  final Color categoryColor;
  final VoidCallback onTap;

  const _HonorSelectItem({
    required this.honor,
    required this.categoryColor,
    required this.onTap,
  });

  @override
  State<_HonorSelectItem> createState() => _HonorSelectItemState();
}

class _HonorSelectItemState extends State<_HonorSelectItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _scaleController.reverse();
    await _scaleController.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.honor.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join('');

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: widget.honor.imageUrl != null &&
                        widget.honor.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.honor.imageUrl!,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => _InitialsBox(
                          initials: initials,
                          categoryColor: widget.categoryColor,
                        ),
                      )
                    : _InitialsBox(
                        initials: initials,
                        categoryColor: widget.categoryColor,
                      ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.honor.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.sac.text,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Initials box ──────────────────────────────────────────────────────────────

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
        shape: BoxShape.circle,
        border: Border.all(color: categoryColor.withAlpha(60), width: 1.5),
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
