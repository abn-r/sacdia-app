import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Género soportado por el backend (`gender` en `UpdateUserDto`).
///
/// El selector vive en `profile_edit_sheets.dart` (`showGenderSheet`).
///
/// - [display] es el label visible al usuario.
/// - [apiKey] es el valor que el backend espera en `PATCH /users/:id`
///   con campo `gender` (validado por `@IsIn(['M', 'F'])`).
enum Gender {
  male('M'),
  female('F');

  const Gender(this.apiKey);

  final String apiKey;

  String display(BuildContext context) {
    switch (this) {
      case Gender.male:
        return 'profile.edit.gender_male'.tr();
      case Gender.female:
        return 'profile.edit.gender_female'.tr();
    }
  }

  HugeIconData get icon {
    switch (this) {
      case Gender.male:
        return HugeIcons.strokeRoundedMale02;
      case Gender.female:
        return HugeIcons.strokeRoundedFemale02;
    }
  }

  static Gender? fromApiKey(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final g in Gender.values) {
      if (g.apiKey == value) return g;
    }
    return null;
  }
}
