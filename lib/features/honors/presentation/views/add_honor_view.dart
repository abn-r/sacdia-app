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

// ── Category color + icon maps ────────────────────────────────────────────────

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
  // Naturaleza usa blanco como color de logo — forzar negro para legibilidad
  if (name == 'Naturaleza' || name == 'Estudio de la naturaleza') {
    return AppColors.sacBlack;
  }
  return color;
}

// ── Data class ────────────────────────────────────────────────────────────────

/// Asocia una especialidad con el nombre de su categoría para el grid plano.
class _HonorWithCategory {
  final Honor honor;
  final String categoryName;

  const _HonorWithCategory({
    required this.honor,
    required this.categoryName,
  });
}

// ── View ──────────────────────────────────────────────────────────────────────

/// Pantalla para agregar una nueva especialidad al perfil del usuario.
///
/// Muestra TODAS las especialidades en un único grid plano de 2 columnas,
/// sin headers de categoría. Incluye buscador pill, chips de filtro con
/// icono + nombre, y tarjetas rediseñadas con imagen, nombre y pill de categoría.
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

  // ── Flatten + filter ────────────────────────────────────────────────────────

  List<_HonorWithCategory> _buildFlatList(List<HonorGroup> groups) {
    // Aplanar todos los grupos en una lista homogénea
    final allHonors = groups
        .expand(
          (g) => g.honors.map(
            (h) => _HonorWithCategory(
              honor: h,
              categoryName: g.category.name,
            ),
          ),
        )
        .toList();

    // Sin filtro de categoría → ordenar alfabéticamente
    if (_selectedCategory == null) {
      allHonors.sort((a, b) => a.honor.name.compareTo(b.honor.name));
    }

    // Filtro de texto
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      allHonors.removeWhere(
        (h) => !h.honor.name.toLowerCase().contains(q),
      );
    }

    // Filtro de categoría
    if (_selectedCategory != null) {
      allHonors.removeWhere((h) => h.categoryName != _selectedCategory);
    }

    return allHonors;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(honorsGroupedByCategoryProvider);

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: _buildAppBar(groupsAsync),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────────────
            _buildSearchBar(context),

            // ── Category filter chips ─────────────────────────────────
            groupsAsync.maybeWhen(
              data: (groups) => _buildCategoryChips(context, groups),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),

            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(child: SacLoading()),
                error: (e, _) => _buildErrorState(context),
                data: (groups) => _buildFlatGrid(context, groups),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

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

  // ── Search bar ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar especialidad...',
          hintStyle: TextStyle(
            color: context.sac.textTertiary,
            fontSize: 14,
          ),
          prefixIcon: Center(
            widthFactor: 1,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 18,
              color: context.sac.textSecondary,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 18,
                    color: context.sac.textSecondary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: context.sac.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: context.sac.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          filled: true,
          fillColor: context.sac.surfaceVariant,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  // ── Category chips ──────────────────────────────────────────────────────────

  Widget _buildCategoryChips(BuildContext context, List<HonorGroup> groups) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Chip "Todas"
          _CategoryChip(
            label: 'Todas',
            icon: Icons.apps_rounded,
            color: AppColors.primary,
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          // Chips de cada categoría
          ...groups.map((group) {
            final name = group.category.name;
            final color = _colorForCategory(name);
            final icon = _categoryIcons[name] ?? Icons.star_rounded;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: name,
                icon: icon,
                color: color,
                isSelected: _selectedCategory == name,
                onTap: () => setState(() {
                  _selectedCategory =
                      _selectedCategory == name ? null : name;
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Flat grid ───────────────────────────────────────────────────────────────

  Widget _buildFlatGrid(BuildContext context, List<HonorGroup> groups) {
    final items = _buildFlatList(groups);

    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final categoryColor = _colorForCategory(item.categoryName);

        return _HonorCard(
          honor: item.honor,
          categoryName: item.categoryName,
          categoryColor: categoryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HonorDetailView(
                  honorId: item.honor.id,
                  initialHonor: item.honor,
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
  }

  // ── Empty state ─────────────────────────────────────────────────────────────

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
                    horizontal: 20,
                    vertical: 10,
                  ),
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

  // ── Error state ─────────────────────────────────────────────────────────────

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

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Naturaleza tiene color blanco — usar negro efectivo para UI
    final effectiveColor =
        color == AppColors.catNaturaleza ? AppColors.sacBlack : color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor
              : effectiveColor.withAlpha(18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? effectiveColor
                : effectiveColor.withAlpha(70),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : effectiveColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Honor card ────────────────────────────────────────────────────────────────

/// Tarjeta de especialidad para el grid plano de 2 columnas.
///
/// Muestra imagen (o fallback de iniciales), nombre en 2 líneas máximo
/// y un pill de categoría en la parte inferior. Usa Material + InkWell
/// para feedback de tap nativo sin AnimationController por item.
class _HonorCard extends StatelessWidget {
  final Honor honor;
  final String categoryName;
  final Color categoryColor;
  final VoidCallback onTap;

  const _HonorCard({
    required this.honor,
    required this.categoryName,
    required this.categoryColor,
    required this.onTap,
  });

  String get _initials => honor.name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join('');

  // Naturaleza tiene color blanco — usar negro efectivo
  Color get _effectiveColor =>
      categoryColor == AppColors.catNaturaleza
          ? AppColors.sacBlack
          : categoryColor;

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _effectiveColor.withAlpha(30),
        highlightColor: _effectiveColor.withAlpha(15),
        child: Ink(
          decoration: BoxDecoration(
            color: sac.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sac.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: sac.shadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image area (~60% of card height) ─────────────────
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: Container(
                    color: _effectiveColor.withAlpha(12),
                    padding: const EdgeInsets.all(12),
                    child: _buildImage(),
                  ),
                ),
              ),
              // ── Name + category pill ──────────────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        honor.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sac.text,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _CategoryPill(
                        label: categoryName,
                        color: _effectiveColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final hasImage = honor.imageUrl != null && honor.imageUrl!.isNotEmpty;

    if (hasImage) {
      return CachedNetworkImage(
        imageUrl: honor.imageUrl!,
        fit: BoxFit.contain,
        placeholder: (_, __) => Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _effectiveColor.withAlpha(120),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _InitialsFallback(
          initials: _initials,
          color: _effectiveColor,
        ),
      );
    }

    return _InitialsFallback(initials: _initials, color: _effectiveColor);
  }
}

// ── Category pill ─────────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  final String label;
  final Color color;

  const _CategoryPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(55), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Initials fallback ─────────────────────────────────────────────────────────

class _InitialsFallback extends StatelessWidget {
  final String initials;
  final Color color;

  const _InitialsFallback({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(70), width: 1.5),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
