import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/setting_tile.dart';

/// Provider para el modo de tema
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // TODO: Cargar desde SharedPreferences
  return ThemeMode.system;
});

/// Vista de configuración de la aplicación
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    setState(() {
      _appVersion = '1.0.0';
    });
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Claro'),
              value: ThemeMode.light,
              groupValue: ref.read(themeModeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).state = value;
                  // TODO: Guardar en SharedPreferences
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Oscuro'),
              value: ThemeMode.dark,
              groupValue: ref.read(themeModeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).state = value;
                  // TODO: Guardar en SharedPreferences
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Sistema'),
              value: ThemeMode.system,
              groupValue: ref.read(themeModeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).state = value;
                  // TODO: Guardar en SharedPreferences
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Estás seguro que deseas cerrar sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: AppColors.sacGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        children: [
          // Sección de Apariencia
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingM),
                  child: Text(
                    'Apariencia',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SettingTile(
                  icon: Icons.palette,
                  title: 'Tema',
                  subtitle: _getThemeName(themeMode),
                  onTap: _showThemeDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingM),
          // Sección de Notificaciones
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingM),
                  child: Text(
                    'Notificaciones',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SettingTile(
                  icon: Icons.notifications,
                  title: 'Notificaciones push',
                  subtitle: 'Recibe notificaciones de actividades',
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {
                      // TODO: Implementar toggle de notificaciones
                    },
                    activeColor: AppColors.sacGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingM),
          // Sección de Cuenta
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingM),
                  child: Text(
                    'Cuenta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SettingTile(
                  icon: Icons.logout,
                  title: 'Cerrar sesión',
                  iconColor: AppColors.error,
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingM),
          // Sección de Acerca de
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingM),
                  child: Text(
                    'Acerca de',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SettingTile(
                  icon: Icons.info,
                  title: 'Versión de la app',
                  subtitle: _appVersion,
                ),
                const Divider(height: 1),
                SettingTile(
                  icon: Icons.privacy_tip,
                  title: 'Política de privacidad',
                  onTap: () {
                    // TODO: Abrir política de privacidad
                  },
                ),
                const Divider(height: 1),
                SettingTile(
                  icon: Icons.description,
                  title: 'Términos y condiciones',
                  onTap: () {
                    // TODO: Abrir términos y condiciones
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
