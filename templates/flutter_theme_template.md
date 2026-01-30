# Guía para Implementación de Temas en Sacdia App

## Estructura de Temas

Los temas están organizados en tres archivos principales:

1. `app_colors.dart` - Define todos los colores utilizados en la aplicación
2. `app_theme.dart` - Define los temas claro y oscuro con todos los estilos 
3. `theme_provider.dart` - Gestiona el tema actual y el cambio entre temas

## Personalización de Colores

En lugar de usar el accentColor tradicional de Material, se usa un enfoque más específico donde cada elemento puede tener colores independientes y personalizados:

### Cómo Añadir Nuevos Colores

```dart
// En app_colors.dart
// Añadir nuevos colores para componentes específicos
static const Color componentBackground = Color(0xFFYOUR_HEX);
static const Color componentText = Color(0xFFYOUR_HEX);
```

### Consideraciones de Accesibilidad

- Asegúrese de que todos los pares de colores de fondo/texto tengan suficiente contraste
- Pruebe los temas con herramientas de accesibilidad
- Use los colores de forma consistente en toda la aplicación

## Personalización de Temas

### Cómo Personalizar el Tema Claro

```dart
// En app_theme.dart - dentro de lightTheme
// Ejemplo para personalizar un componente:
componentTheme: ComponentTheme(
  backgroundColor: AppColors.lightBackground,
  textColor: AppColors.lightText,
  borderColor: AppColors.lightDivider,
),
```

### Cómo Personalizar el Tema Oscuro

```dart
// En app_theme.dart - dentro de darkTheme
// Ejemplo para personalizar un componente:
componentTheme: ComponentTheme(
  backgroundColor: AppColors.darkBackground,
  textColor: AppColors.darkText,
  borderColor: AppColors.darkDivider,
),
```

## Uso en Widgets

### Cómo Usar los Temas en Widgets

```dart
// Acceder a colores del tema actual
final primaryColor = Theme.of(context).colorScheme.primary;

// Acceder a colores específicos (independientes del tema)
final specificColor = AppColors.primaryBlue;

// Acceder a estilos de texto
final titleStyle = Theme.of(context).textTheme.titleLarge;
```

### Widgets Sensibles al Tema

Para crear widgets que respondan automáticamente al cambio de tema:

```dart
class ThemeSensitiveWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Detecta automáticamente el tema actual
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
      child: Text(
        'Este widget responde al tema',
        style: TextStyle(
          color: isDarkMode ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }
}
```

## Cambiando Temas

Para permitir al usuario cambiar entre temas:

```dart
// En un widget que controla el tema
final themeProvider = Provider.of<ThemeProvider>(context);

// Cambiar a tema claro
ElevatedButton(
  onPressed: () => themeProvider.setLightTheme(),
  child: Text('Tema Claro'),
),

// Cambiar a tema oscuro
ElevatedButton(
  onPressed: () => themeProvider.setDarkTheme(),
  child: Text('Tema Oscuro'),
),

// Alternar entre temas
IconButton(
  icon: Icon(Icons.brightness_6),
  onPressed: () => themeProvider.toggleTheme(),
),
```

## Mejores Prácticas

1. **Consistencia**: Utilice los colores de manera consistente en toda la aplicación
2. **Especificidad**: Defina colores específicos para cada parte de su interfaz
3. **Testing**: Pruebe su aplicación en ambos temas para detectar problemas visuales
4. **Accesibilidad**: Asegúrese de que todos los elementos sean visibles en ambos temas
5. **Personalización**: Adapte los temas a la identidad visual de su marca
