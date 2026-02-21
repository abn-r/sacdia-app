import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';

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
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (context) => _ThemePickerDialog(
        currentMode: ref.read(themeModeProvider),
        onModeSelected: (mode) {
          ref.read(themeModeProvider.notifier).state = mode;
          // TODO: Guardar en SharedPreferences
          Navigator.pop(context);
        },
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
    final shouldLogout = await SacDialog.show(
      context,
      title: 'Cerrar sesión',
      content: '¿Estás seguro que deseas cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
      confirmIsDestructive: true,
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Apariencia
          SacCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPaintBrush01,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Apariencia',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                SettingTile(
                  icon: HugeIcons.strokeRoundedPaintBrush01,
                  title: 'Tema',
                  subtitle: _getThemeName(themeMode),
                  onTap: _showThemeDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sección de Notificaciones
          SacCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedNotification01,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Notificaciones',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                SettingTile(
                  icon: HugeIcons.strokeRoundedNotification01,
                  title: 'Notificaciones push',
                  subtitle: 'Recibe notificaciones de actividades',
                  trailing: Switch.adaptive(
                    value: true,
                    onChanged: (value) {
                      // TODO: Implementar toggle de notificaciones
                    },
                    activeColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sección de Cuenta
          SacCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cuenta',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                SettingTile(
                  icon: HugeIcons.strokeRoundedLogout01,
                  title: 'Cerrar sesión',
                  iconColor: AppColors.error,
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sección de Acerca de
          SacCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Acerca de',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                SettingTile(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  title: 'Versión de la app',
                  subtitle: _appVersion,
                ),
                const Divider(height: 1),
                SettingTile(
                  icon: HugeIcons.strokeRoundedSecurityCheck,
                  title: 'Política de privacidad',
                  onTap: () {
                    // TODO: Abrir política de privacidad
                  },
                ),
                const Divider(height: 1),
                SettingTile(
                  icon: HugeIcons.strokeRoundedLegalDocument01,
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

/// SACDIA-styled theme picker dialog — multi-option, no confirm/cancel.
class _ThemePickerDialog extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onModeSelected;

  const _ThemePickerDialog({
    required this.currentMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;

    final options = [
      (ThemeMode.light, 'Claro', HugeIcons.strokeRoundedSun01),
      (ThemeMode.dark, 'Oscuro', HugeIcons.strokeRoundedMoon01),
      (ThemeMode.system, 'Sistema', HugeIcons.strokeRoundedSmartPhone01),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: _ScaleFadeIn(
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Text(
                  'Seleccionar Tema',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(height: 0.5, color: AppColors.lightBorder),
              // Options
              ...options.map((entry) {
                final (mode, label, icon) = entry;
                final isSelected = currentMode == mode;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => onModeSelected(mode),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: icon,
                              size: 20,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedTick02,
                                size: 18,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (mode != ThemeMode.system)
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.only(left: 52),
                        color: AppColors.lightBorder,
                      ),
                  ],
                );
              }),
              // Cancel row
              Container(height: 0.5, color: AppColors.lightBorder),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.lightTextSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                  shape: const RoundedRectangleBorder(),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scale + fade entrance animation for SACDIA-styled dialogs.
class _ScaleFadeIn extends StatefulWidget {
  final Widget child;

  const _ScaleFadeIn({required this.child});

  @override
  State<_ScaleFadeIn> createState() => _ScaleFadeInState();
}

class _ScaleFadeInState extends State<_ScaleFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
        .drive(Tween<double>(begin: 0.82, end: 1.0));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut)
        .drive(Tween<double>(begin: 0.0, end: 1.0));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => FadeTransition(
        opacity: _fade,
        child: ScaleTransition(scale: _scale, child: child),
      ),
      child: widget.child,
    );
  }
}
