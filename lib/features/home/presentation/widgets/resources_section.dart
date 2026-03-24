import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS (hardcoded mock)
// ─────────────────────────────────────────────────────────────────────────────

enum ResourceType { pdf, image, audio, document }

class ResourceFile {
  final String name;
  final String size;
  final ResourceType type;
  final String uploadedAt;

  const ResourceFile({
    required this.name,
    required this.size,
    required this.type,
    required this.uploadedAt,
  });
}

class ResourceCategory {
  final String name;
  final int fileCount;
  final Color color;

  const ResourceCategory({
    required this.name,
    required this.fileCount,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA
// ─────────────────────────────────────────────────────────────────────────────

const _mockFiles = <ResourceFile>[
  ResourceFile(
    name: 'Manual del Conquistador 2025',
    size: '3.4 MB',
    type: ResourceType.pdf,
    uploadedAt: 'Hace 2 días',
  ),
  ResourceFile(
    name: 'Formulario de Inscripción',
    size: '128 KB',
    type: ResourceType.document,
    uploadedAt: 'Hace 5 días',
  ),
  ResourceFile(
    name: 'Foto Club Montaña Verde',
    size: '2.1 MB',
    type: ResourceType.image,
    uploadedAt: 'Hace 1 semana',
  ),
  ResourceFile(
    name: 'Himno de los Conquistadores',
    size: '4.7 MB',
    type: ResourceType.audio,
    uploadedAt: 'Hace 2 semanas',
  ),
  ResourceFile(
    name: 'Reglamento Interno del Club',
    size: '890 KB',
    type: ResourceType.pdf,
    uploadedAt: 'Hace 1 mes',
  ),
];

const _mockCategories = <ResourceCategory>[
  ResourceCategory(
    name: 'Formatos',
    fileCount: 12,
    color: AppColors.primary,
  ),
  ResourceCategory(
    name: 'Manuales',
    fileCount: 8,
    color: AppColors.sacBlue,
  ),
  ResourceCategory(
    name: 'Imágenes',
    fileCount: 34,
    color: AppColors.secondary,
  ),
  ResourceCategory(
    name: 'Música',
    fileCount: 6,
    color: AppColors.accent,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Sección de Recursos para la pantalla de inicio.
///
/// Muestra filtros de tipo de archivo, archivos recientes en scroll horizontal
/// y categorías de carpetas en grilla 2 columnas.
class ResourcesSection extends StatefulWidget {
  const ResourcesSection({super.key});

  @override
  State<ResourcesSection> createState() => _ResourcesSectionState();
}

class _ResourcesSectionState extends State<ResourcesSection> {
  ResourceType? _activeFilter; // null = "Todos"

  List<ResourceFile> get _filteredFiles => _activeFilter == null
      ? _mockFiles
      : _mockFiles.where((f) => f.type == _activeFilter).toList();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.sac.background,
        foregroundColor: context.sac.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: context.sac.text,
            size: 22,
          ),
          onPressed: () => context.go(RouteNames.homeDashboard),
          tooltip: 'Volver',
        ),
        title: Text(
          'Recursos',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: context.sac.text,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.sac.border),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedFolder02,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recursos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver todo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
          
              // ── Filter chips ─────────────────────────────────────────
              _FilterChipsRow(
                activeFilter: _activeFilter,
                onFilterChanged: (type) => setState(() => _activeFilter = type),
              ),
              const SizedBox(height: 18),
          
              // ── Archivos recientes ────────────────────────────────────
              Text(
                'Archivos Recientes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 148,
                child: _filteredFiles.isEmpty
                    ? Center(
                        child: Text(
                          'No hay archivos en esta categoría',
                          style: TextStyle(fontSize: 13, color: c.textTertiary),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: _filteredFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) =>
                            _FileCard(file: _filteredFiles[index]),
                      ),
              ),
              const SizedBox(height: 22),
          
              // ── Categorías ───────────────────────────────────────────
              Text(
                'Categorías',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemCount: _mockCategories.length,
                itemBuilder: (context, index) =>
                    _CategoryCard(category: _mockCategories[index]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIPS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  final ResourceType? activeFilter;
  final ValueChanged<ResourceType?> onFilterChanged;

  const _FilterChipsRow({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _Chip(
            label: 'Todos',
            icon: HugeIcons.strokeRoundedGridView,
            isActive: activeFilter == null,
            onTap: () => onFilterChanged(null),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Documentos',
            icon: HugeIcons.strokeRoundedFile01,
            isActive: activeFilter == ResourceType.pdf ||
                activeFilter == ResourceType.document,
            onTap: () => onFilterChanged(ResourceType.pdf),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Imágenes',
            icon: HugeIcons.strokeRoundedImage01,
            isActive: activeFilter == ResourceType.image,
            onTap: () => onFilterChanged(ResourceType.image),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Audio',
            icon: HugeIcons.strokeRoundedHeadphones,
            isActive: activeFilter == ResourceType.audio,
            onTap: () => onFilterChanged(ResourceType.audio),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final List<List<dynamic>> icon;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isActive ? AppColors.primary : c.border,
            width: 1.2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: 15,
              color: isActive ? Colors.white : c.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILE CARD (horizontal scroll item)
// ─────────────────────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final ResourceFile file;

  const _FileCard({required this.file});

  Color get _typeColor {
    switch (file.type) {
      case ResourceType.pdf:
        return AppColors.primary;
      case ResourceType.document:
        return AppColors.sacBlue;
      case ResourceType.image:
        return AppColors.secondary;
      case ResourceType.audio:
        return AppColors.accent;
    }
  }

  List<List<dynamic>> get _typeIcon {
    switch (file.type) {
      case ResourceType.pdf:
        return HugeIcons.strokeRoundedPdf01;
      case ResourceType.document:
        return HugeIcons.strokeRoundedDoc01;
      case ResourceType.image:
        return HugeIcons.strokeRoundedImage01;
      case ResourceType.audio:
        return HugeIcons.strokeRoundedMusicNote01;
    }
  }

  String get _typeLabel {
    switch (file.type) {
      case ResourceType.pdf:
        return 'PDF';
      case ResourceType.document:
        return 'DOC';
      case ResourceType.image:
        return 'IMG';
      case ResourceType.audio:
        return 'MP3';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail / icon area
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      HugeIcon(
                        icon: _typeIcon,
                        size: 22,
                        color: _typeColor,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: _typeColor,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXS),
                          ),
                          child: Text(
                            _typeLabel,
                            style: const TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // File name
                Text(
                  file.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Size
                Text(
                  file.size,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY CARD (grid item)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final ResourceCategory category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Folder icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedFolder02,
                      size: 22,
                      color: category.color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${category.fileCount} archivos',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
