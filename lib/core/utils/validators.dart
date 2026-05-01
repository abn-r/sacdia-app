import 'package:easy_localization/easy_localization.dart';

/// Clase para validar campos de formularios y entradas de usuario
class Validators {
  Validators._();

  /// Valida un email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return tr('core.validators.email_required');
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return tr('core.validators.email_invalid');
    }

    return null;
  }

  /// Valida una contraseña.
  ///
  /// Requisitos (en línea con lo que exige el backend):
  ///   - Mínimo 8 caracteres
  ///   - Al menos una letra mayúscula
  ///   - Al menos una letra minúscula
  ///   - Al menos un dígito
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return tr('core.validators.password_required');
    }

    if (value.length < 8) {
      return tr('core.validators.password_min_length');
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return tr('core.validators.password_uppercase');
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return tr('core.validators.password_lowercase');
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return tr('core.validators.password_number');
    }

    return null;
  }

  /// Valida que ambas contraseñas coincidan
  static String? validatePasswordMatch(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return tr('core.validators.confirm_password_required');
    }

    if (password != confirmPassword) {
      return tr('core.validators.passwords_mismatch');
    }

    return null;
  }

  /// Valida un nombre
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return tr('core.validators.name_required');
    }

    if (value.length < 2) {
      return tr('core.validators.name_min_length');
    }

    return null;
  }

  /// Valida un número de teléfono
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Teléfono opcional
    }

    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return tr('core.validators.phone_invalid');
    }

    return null;
  }

  /// Valida un campo requerido
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '${fieldName.substring(0, 1).toUpperCase()}${fieldName.substring(1)} es requerido';
    }

    return null;
  }

  /// Valida una URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL opcional
    }

    final urlRegex = RegExp(
      r'^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return tr('core.validators.url_invalid');
    }

    return null;
  }
}
