import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Extensiones para objetos String
extension StringExtensions on String {
  /// Capitaliza la primera letra de un String
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
  
  /// Convierte snake_case a camelCase
  String get toCamelCase {
    if (isEmpty) return this;
    
    List<String> parts = split('_');
    String result = parts[0].toLowerCase();
    
    for (int i = 1; i < parts.length; i++) {
      result += parts[i].capitalize;
    }
    
    return result;
  }
  
  /// Convierte un String a una fecha
  DateTime? toDateTime({String format = 'yyyy-MM-dd'}) {
    try {
      return DateFormat(format).parse(this);
    } catch (_) {
      return null;
    }
  }
  
  /// Verifica si un String es un email
  bool get isEmail {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(this);
  }
  
  /// Verifica si un String es una URL
  bool get isUrl {
    return RegExp(
      r'^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    ).hasMatch(this);
  }
}

/// Extensiones para objetos DateTime
extension DateTimeExtensions on DateTime {
  /// Formatea la fecha con el formato especificado
  String format({String format = 'dd/MM/yyyy'}) {
    return DateFormat(format).format(this);
  }
  
  /// Verifica si la fecha es hoy
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  /// Verifica si la fecha es ayer
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }
  
  /// Verifica si la fecha es mañana
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }
}

/// Extensiones para BuildContext
extension ContextExtensions on BuildContext {
  /// Obtener el tamaño de la pantalla
  Size get screenSize => MediaQuery.of(this).size;
  
  /// Obtener la altura de la pantalla
  double get screenHeight => screenSize.height;
  
  /// Obtener el ancho de la pantalla
  double get screenWidth => screenSize.width;
  
  /// Obtener el tema actual
  ThemeData get theme => Theme.of(this);
  
  /// Obtener los colores del tema
  ColorScheme get colors => theme.colorScheme;
  
  /// Obtener los estilos de texto del tema
  TextTheme get textTheme => theme.textTheme;
  
  /// Navegar a una nueva pantalla
  Future<T?> pushNamed<T>(String route, {Object? arguments}) {
    return Navigator.of(this).pushNamed<T>(route, arguments: arguments);
  }
  
  /// Reemplazar la pantalla actual con una nueva
  Future<T?> pushReplacementNamed<T, TO>(String route, {TO? result, Object? arguments}) {
    return Navigator.of(this).pushReplacementNamed<T, TO>(
      route, 
      result: result,
      arguments: arguments,
    );
  }
  
  /// Eliminar todas las pantallas anteriores y navegar a una nueva
  Future<T?> pushNamedAndRemoveUntil<T>(String route, {Object? arguments}) {
    return Navigator.of(this).pushNamedAndRemoveUntil<T>(
      route, 
      (route) => false,
      arguments: arguments,
    );
  }
  
  /// Regresar a la pantalla anterior
  void pop<T>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }
  
  /// Mostrar un SnackBar
  void showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? colors.primary,
      ),
    );
  }
}

/// Extensiones para AsyncValue de Riverpod
extension AsyncValueExtensions<T> on AsyncValue<T> {
  // Eliminamos el método valueOrNull ya que ya existe en AsyncValueX de Riverpod
  // y usaremos ese directamente
  
  /// Verifica si el AsyncValue es exitoso (tiene datos, no está en error ni cargando)
  bool get isSuccess => !isLoading && !hasError && hasValue;
}
