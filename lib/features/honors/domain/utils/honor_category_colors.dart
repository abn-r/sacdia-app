import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Primary lookup by category ID — stable even if names change in the future.
///
/// IDs sourced from the `honors_categories` table (production):
///   1 → ADRA
///   2 → Actividades Agropecuarias
///   3 → Ciencias de la Salud
///   4 → Artes Domésticas
///   5 → Artes y Actividades Manuales
///   6 → Crecimiento Espiritual, Actividades Misioneras y Herencia
///   7 → Estudio de la Naturaleza
///   8 → Actividades Vocacionales
///   9 → Actividades Recreativas
const Map<int, Color> kCategoryColorById = {
  1: AppColors.catAdra,
  2: AppColors.catagropecuarias,
  3: AppColors.catCienciasSalud,
  4: AppColors.catDomesticas,
  5: AppColors.catHabilidadesManuales,
  6: AppColors.catMisioneras,
  7: AppColors.catNaturaleza,
  8: AppColors.catProfesionales,
  9: AppColors.catRecreativas,
};

/// Fallback lookup by category name — used when [honorCategoryId] is unavailable.
const Map<String, Color> kCategoryColorByName = {
  'ADRA': AppColors.catAdra,
  'Actividades Agropecuarias': AppColors.catagropecuarias,
  'Ciencias de la Salud': AppColors.catCienciasSalud,
  'Artes Domésticas': AppColors.catDomesticas,
  'Artes y Actividades Manuales': AppColors.catHabilidadesManuales,
  'Crecimiento Espiritual, Actividades Misioneras y Herencia':
      AppColors.catMisioneras,
  'Estudio de la Naturaleza': AppColors.catNaturaleza,
  'Actividades Vocacionales': AppColors.catProfesionales,
  'Actividades Recreativas': AppColors.catRecreativas,
};

/// Resolves the category [Color] using [categoryId] as primary key and
/// [categoryName] as fallback. Returns [AppColors.sacBlue] if neither matches.
Color getCategoryColor({int? categoryId, String? categoryName}) {
  if (categoryId != null) {
    final color = kCategoryColorById[categoryId];
    if (color != null) return color;
  }
  if (categoryName != null) {
    final color = kCategoryColorByName[categoryName];
    if (color != null) return color;
  }
  return AppColors.sacBlue;
}
