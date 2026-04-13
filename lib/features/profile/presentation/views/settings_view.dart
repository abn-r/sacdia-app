import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/logout_cleanup.dart';
import '../widgets/setting_tile.dart';
import 'template_view.dart';
import 'template_1_view.dart';

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

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool currentObscure = true;
    bool newObscure = true;
    bool confirmObscure = true;
    String? errorText;

    final submitted = await showDialog<bool>(
      context: context,
      barrierColor: context.sac.barrierColor,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar contraseña'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentCtrl,
                    obscureText: currentObscure,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Contraseña actual',
                      suffixIcon: IconButton(
                        icon: Icon(currentObscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setDialogState(
                            () => currentObscure = !currentObscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    obscureText: newObscure,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(newObscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setDialogState(() => newObscure = !newObscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: confirmObscure,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(confirmObscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setDialogState(
                            () => confirmObscure = !confirmObscure),
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final current = currentCtrl.text.trim();
                    final next = newCtrl.text.trim();
                    final confirm = confirmCtrl.text.trim();

                    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                      setDialogState(
                          () => errorText = 'Completa todos los campos.');
                      return;
                    }
                    if (next != confirm) {
                      setDialogState(() =>
                          errorText = 'Las contraseñas nuevas no coinciden.');
                      return;
                    }
                    if (next.length < 8) {
                      setDialogState(() => errorText =
                          'La contraseña debe tener al menos 8 caracteres.');
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Cambiar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true || !mounted) return;

    final error = await ref
        .read(authNotifierProvider.notifier)
        .updatePassword(
          currentPassword: currentCtrl.text.trim(),
          newPassword: newCtrl.text.trim(),
        );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Contraseña actualizada correctamente.'),
        backgroundColor: error != null ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog<void>(
      context: context,
      barrierColor: context.sac.barrierColor,
      barrierDismissible: true,
      builder: (context) => _ThemePickerDialog(
        currentMode: ref.read(themeNotifierProvider),
        onModeSelected: (mode) {
          final notifier = ref.read(themeNotifierProvider.notifier);
          switch (mode) {
            case ThemeMode.light:
              notifier.setLightTheme();
            case ThemeMode.dark:
              notifier.setDarkTheme();
            case ThemeMode.system:
              notifier.setSystemTheme();
          }
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
      final success = await ref.read(authNotifierProvider.notifier).signOut();
      if (success) clearUserStateOnLogout(ref);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);

    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: c.surfaceVariant,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── APARIENCIA ────────────────────────────────────────────
          _SectionHeader(title: 'APARIENCIA'),
          _GroupContainer(
            children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedPaintBrush01,
                title: 'Tema',
                subtitle: _getThemeName(themeMode),
                iconColor: AppColors.primary,
                onTap: _showThemeDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── DESARROLLO ───────────────────────────────────────────
          _SectionHeader(title: 'DESARROLLO'),
          _GroupContainer(
            children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedUserAccount,
                title: 'Mockup: Pantalla de Perfil',
                subtitle: 'Vista de diseño (datos de prueba)',
                iconColor: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              ),
              _groupDivider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedUserStar01,
                title: 'Mockup: Información Personal',
                subtitle: 'Alergias, enfermedades y contactos (datos de prueba)',
                iconColor: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MockPersonalInfoScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── ACERCA DE ─────────────────────────────────────────────
          _SectionHeader(title: 'ACERCA DE'),
          _GroupContainer(
            children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedInformationCircle,
                title: 'Versión de la app',
                subtitle: _appVersion,
              ),
              _groupDivider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedSecurityCheck,
                title: 'Política de privacidad',
                onTap: () async {
                  await launchUrl(
                    Uri.parse('https://sacdia.com/privacy'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              _groupDivider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedLegalDocument01,
                title: 'Términos y condiciones',
                onTap: () async {
                  await launchUrl(
                    Uri.parse('https://sacdia.com/terms'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── CUENTA ────────────────────────────────────────────────
          _SectionHeader(title: 'CUENTA'),
          _GroupContainer(
            children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedLockPassword,
                title: 'Cambiar contraseña',
                iconColor: AppColors.primary,
                onTap: _showChangePasswordDialog,
              ),
              _groupDivider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedLogout01,
                title: 'Cerrar sesión',
                iconColor: AppColors.error,
                onTap: _handleLogout,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _groupDivider() => Divider(
        height: 1,
        thickness: 1,
        indent: 60,
        color: context.sac.borderLight,
      );
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
    final c = context.sac;

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
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.sac.shadow,
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
              Container(height: 0.5, color: c.border),
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
                                  : c.textSecondary,
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
                                      : c.textSecondary,
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
                        color: c.border,
                      ),
                  ],
                );
              }),
              // Cancel row
              Container(height: 0.5, color: c.border),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: c.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: c.textSecondary,
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

/// Header de sección estilo iOS — uppercase, pequeño, gris.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.sac.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Contenedor agrupado estilo iOS Settings — fondo blanco, bordes redondeados.
class _GroupContainer extends StatelessWidget {
  final List<Widget> children;

  const _GroupContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.sac.border, width: 1),
      ),
      child: Column(children: children),
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
