# 📱 Template Flutter Feature - MVVM + Clean Architecture

## 🏗️ Estructura de Directorios a Generar

```
lib/features/{{FEATURE_NAME}}/
│
├── 📂 data/
│   ├── 📂 datasources/
│   │   ├── 📄 {{feature_name}}_local_datasource.dart
│   │   └── 📄 {{feature_name}}_remote_datasource.dart
│   │
│   ├── 📂 models/
│   │   └── 📄 {{feature_name}}_model.dart
│   │
│   └── 📂 repositories/
│       └── 📄 {{feature_name}}_repository_impl.dart
│
├── 📂 domain/
│   ├── 📂 entities/
│   │   └── 📄 {{feature_name}}_entity.dart
│   │
│   ├── 📂 repositories/
│   │   └── 📄 {{feature_name}}_repository.dart
│   │
│   └── 📂 usecases/
│       ├── 📄 get_{{feature_name}}.dart
│       ├── 📄 create_{{feature_name}}.dart
│       ├── 📄 update_{{feature_name}}.dart
│       └── 📄 delete_{{feature_name}}.dart
│
└── 📂 presentation/
    ├── 📂 viewmodels/
    │   └── 📄 {{feature_name}}_viewmodel.dart
    │
    ├── 📂 views/
    │   ├── 📄 {{feature_name}}_screen.dart
    │   └── 📄 {{feature_name}}_detail_screen.dart
    │
    └── 📂 widgets/
        ├── 📄 {{feature_name}}_card.dart
        ├── 📄 {{feature_name}}_list_item.dart
        └── 📄 {{feature_name}}_form.dart
```

## 📋 Archivos de Documentación Automática

```
documentation/features/{{FEATURE_NAME}}/
│
├── 📄 architecture.md          # Diagrama de arquitectura del feature
├── 📄 data_flow.md            # Flujo completo de datos
├── 📄 implementation.md       # Detalles de implementación
└── 📄 api_contracts.md        # Contratos de API utilizados
```

## 🎯 Comando para Generar

```bash
@windsurf genera feature {{FEATURE_NAME}} usando template flutter
```

### Ejemplo de uso:
```bash
@windsurf genera feature authentication usando template flutter
```

Esto creará:
```
lib/features/authentication/
├── 📂 data/
│   ├── 📂 datasources/
│   │   ├── 📄 authentication_local_datasource.dart
│   │   └── 📄 authentication_remote_datasource.dart
│   ├── 📂 models/
│   │   └── 📄 authentication_model.dart
│   └── 📂 repositories/
│       └── 📄 authentication_repository_impl.dart
├── 📂 domain/
│   ├── 📂 entities/
│   │   └── 📄 authentication_entity.dart
│   ├── 📂 repositories/
│   │   └── 📄 authentication_repository.dart
│   └── 📂 usecases/
│       ├── 📄 get_authentication.dart
│       ├── 📄 create_authentication.dart
│       ├── 📄 update_authentication.dart
│       └── 📄 delete_authentication.dart
└── 📂 presentation/
    ├── 📂 viewmodels/
    │   └── 📄 authentication_viewmodel.dart
    ├── 📂 views/
    │   ├── 📄 authentication_screen.dart
    │   └── 📄 authentication_detail_screen.dart
    └── 📂 widgets/
        ├── 📄 authentication_card.dart
        ├── 📄 authentication_list_item.dart
        └── 📄 authentication_form.dart
```

## 🔧 Variables del Template

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `{{FEATURE_NAME}}` | Nombre del feature en PascalCase | `Authentication` |
| `{{feature_name}}` | Nombre del feature en snake_case | `authentication` |

## 🚀 Archivos Base Generados Automáticamente

### 1. Entity (Domain Layer)
```dart
// {{feature_name}}_entity.dart
class {{FEATURE_NAME}}Entity {
  final String id;
  final String name;
  
  const {{FEATURE_NAME}}Entity({
    required this.id,
    required this.name,
  });
}
```

### 2. Repository Interface (Domain Layer)
```dart
// {{feature_name}}_repository.dart
abstract class {{FEATURE_NAME}}Repository {
  Future<List<{{FEATURE_NAME}}Entity>> getAll();
  Future<{{FEATURE_NAME}}Entity> getById(String id);
  Future<{{FEATURE_NAME}}Entity> create({{FEATURE_NAME}}Entity entity);
  Future<{{FEATURE_NAME}}Entity> update({{FEATURE_NAME}}Entity entity);
  Future<void> delete(String id);
}
```

### 3. ViewModel (Presentation Layer)
```dart
// {{feature_name}}_viewmodel.dart
class {{FEATURE_NAME}}ViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  List<{{FEATURE_NAME}}Entity> _items = [];
  String _errorMessage = '';
  
  // Getters, methods, etc.
}
```

## ✅ Checklist de Generación

- [ ] Crear estructura de directorios
- [ ] Generar archivos base con boilerplate
- [ ] Configurar inyección de dependencias
- [ ] Crear documentación automática
- [ ] Añadir tests unitarios base
- [ ] Actualizar exports principales