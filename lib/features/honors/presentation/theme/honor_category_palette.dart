import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Fallback lookup by current category ID.
///
/// Do not treat these IDs as a semantic contract: `honors_categories` uses an
/// autoincrement PK and admin can create/update category records. Prefer
/// [kCategoryColorByName] whenever the category name is available.
const Map<int, Color> kCategoryColorById = {
  1: AppColors.catAdra,
  2: AppColors.catAgropecuarias,
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
  'Actividades Agropecuarias': AppColors.catAgropecuarias,
  'Ciencias de la Salud': AppColors.catCienciasSalud,
  'Salud y Ciencia': AppColors.catCienciasSalud,
  'Artes Domésticas': AppColors.catDomesticas,
  'Artes y Actividades Manuales': AppColors.catHabilidadesManuales,
  'Crecimiento Espiritual, Actividades Misioneras y Herencia':
      AppColors.catMisioneras,
  'Estudio de la Naturaleza': AppColors.catNaturaleza,
  'Actividades Vocacionales': AppColors.catProfesionales,
  'Artes Vocacionales': AppColors.catProfesionales,
  'Actividades Recreativas': AppColors.catRecreativas,
  'Actividades Recreacionales': AppColors.catRecreativas,
  'Doctrinales': AppColors.catDoctrinales,
};

/// Accent/border lookup by category name, matching the official visual table.
const Map<String, Color> kCategoryAccentColorByName = {
  'ADRA': AppColors.catAdraBorde,
  'Actividades Agropecuarias': AppColors.catAgropecuariasBorde,
  'Ciencias de la Salud': AppColors.catCienciasSaludBorde,
  'Salud y Ciencia': AppColors.catCienciasSaludBorde,
  'Artes Domésticas': AppColors.catDomesticasBorde,
  'Artes y Actividades Manuales': AppColors.catHabilidadesManualesBorde,
  'Crecimiento Espiritual, Actividades Misioneras y Herencia':
      AppColors.catMisionerasBorde,
  'Estudio de la Naturaleza': AppColors.catNaturalezaBorde,
  'Actividades Vocacionales': AppColors.catProfesionalesBorde,
  'Artes Vocacionales': AppColors.catProfesionalesBorde,
  'Actividades Recreativas': AppColors.catRecreativasBorde,
  'Actividades Recreacionales': AppColors.catRecreativasBorde,
  'Doctrinales': AppColors.catDoctrinalesBorde,
};

/// Resolves the category [Color] using [categoryName] first because names are
/// the only stable semantic value currently exposed by the API. [categoryId] is
/// kept only as a compatibility fallback for screens that still receive IDs.
Color getCategoryColor({int? categoryId, String? categoryName}) {
  if (categoryName != null) {
    final color = kCategoryColorByName[categoryName];
    if (color != null) return color;
  }

  if (categoryId != null) {
    final color = kCategoryColorById[categoryId];
    if (color != null) return color;
  }

  return AppColors.info;
}

/// Resolves the category accent/border [Color] using [categoryName].
/// Falls back to the main category color when no accent exists.
Color getCategoryAccentColor({int? categoryId, String? categoryName}) {
  if (categoryName != null) {
    final color = kCategoryAccentColorByName[categoryName];
    if (color != null) return color;
  }

  return getCategoryColor(categoryId: categoryId, categoryName: categoryName);
}
