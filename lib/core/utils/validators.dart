/// Clase para validar campos de formularios y entradas de usuario
class Validators {
  Validators._();
  
  /// Valida un email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Por favor, ingrese un email válido';
    }
    
    return null;
  }
  
  /// Valida una contraseña
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    
    return null;
  }
  
  /// Valida que ambas contraseñas coincidan
  static String? validatePasswordMatch(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Por favor, confirme su contraseña';
    }
    
    if (password != confirmPassword) {
      return 'Las contraseñas no coinciden';
    }
    
    return null;
  }
  
  /// Valida un nombre
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'El nombre es requerido';
    }
    
    if (value.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
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
      return 'Por favor, ingrese un número de teléfono válido';
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
      return 'Por favor, ingrese una URL válida';
    }
    
    return null;
  }
}
