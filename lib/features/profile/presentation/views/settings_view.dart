import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/logout_cleanup.dart';
import '../providers/notification_preferences_providers.dart';
import '../widgets/setting_tile.dart';
import '../../../qr/presentation/views/member_qr_view.dart';
import 'active_sessions_view.dart';
import 'data_export_view.dart';
import 'edit_profile_view.dart';

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
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${info.version} (${info.buildNumber})';
      });
    }
  }

  /// Aplica un cambio de preferencia con optimistic update.
  ///
  /// Llama PATCH /users/me/notification-preferences con el delta.
  /// Revierte automáticamente si el backend falla y muestra snackbar de error.
  Future<void> _saveNotifPref(Map<String, bool> delta) async {
    final error = await ref
        .read(notificationPreferencesProvider.notifier)
        .patch(delta);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool currentObscure = true;
    bool newObscure = true;
    bool confirmObscure = true;
    String? errorText;
    bool isLoading = false;

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
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Contraseña actual',
                      suffixIcon: IconButton(
                        icon: HugeIcon(
                          icon: currentObscure
                              ? HugeIcons.strokeRoundedViewOffSlash
                              : HugeIcons.strokeRoundedView,
                          size: 20,
                          color: ctx.sac.textSecondary,
                        ),
                        onPressed: isLoading
                            ? null
                            : () => setDialogState(
                                () => currentObscure = !currentObscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    obscureText: newObscure,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      suffixIcon: IconButton(
                        icon: HugeIcon(
                          icon: newObscure
                              ? HugeIcons.strokeRoundedViewOffSlash
                              : HugeIcons.strokeRoundedView,
                          size: 20,
                          color: ctx.sac.textSecondary,
                        ),
                        onPressed: isLoading
                            ? null
                            : () => setDialogState(
                                () => newObscure = !newObscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: confirmObscure,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                      suffixIcon: IconButton(
                        icon: HugeIcon(
                          icon: confirmObscure
                              ? HugeIcons.strokeRoundedViewOffSlash
                              : HugeIcons.strokeRoundedView,
                          size: 20,
                          color: ctx.sac.textSecondary,
                        ),
                        onPressed: isLoading
                            ? null
                            : () => setDialogState(
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
                  onPressed:
                      isLoading ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final current = currentCtrl.text.trim();
                          final next = newCtrl.text.trim();
                          final confirm = confirmCtrl.text.trim();

                          if (current.isEmpty ||
                              next.isEmpty ||
                              confirm.isEmpty) {
                            setDialogState(() =>
                                errorText = 'Completa todos los campos.');
                            return;
                          }
                          if (next != confirm) {
                            setDialogState(() => errorText =
                                'Las contraseñas nuevas no coinciden.');
                            return;
                          }
                          if (next.length < 8) {
                            setDialogState(() => errorText =
                                'La contraseña debe tener al menos 8 caracteres.');
                            return;
                          }
                          setDialogState(() {
                            errorText = null;
                            isLoading = true;
                          });
                          Navigator.pop(ctx, true);
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Cambiar'),
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

  Future<void> _handleDeleteAccount() async {
    final c = context.sac;
    final confirmCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String? fieldError;
    bool isLoading = false;
    bool passwordObscure = true;

    final firstConfirmed = await SacDialog.show(
      context,
      title: 'Eliminar cuenta',
      content:
          'Esta acción es irreversible. Se eliminarán todos tus datos, historial y progreso. ¿Deseas continuar?',
      confirmLabel: 'Continuar',
      confirmIsDestructive: true,
    );

    if (firstConfirmed != true || !mounted) return;

    // Segunda confirmación: escribir "ELIMINAR" + contraseña actual.
    final secondConfirmed = await showDialog<bool>(
      context: context,
      barrierColor: c.barrierColor,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Confirmar eliminación',
            style: TextStyle(color: AppColors.error),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escribí ELIMINAR para confirmar.',
                style: TextStyle(fontSize: 14, color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                autofocus: true,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (old, val) => val.copyWith(
                      text: val.text.toUpperCase(),
                      selection: val.selection,
                    ),
                  ),
                ],
                decoration: const InputDecoration(
                  hintText: 'ELIMINAR',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ingresá tu contraseña actual para continuar.',
                style: TextStyle(fontSize: 14, color: c.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: passwordObscure,
                enabled: !isLoading,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: HugeIcon(
                      icon: passwordObscure
                          ? HugeIcons.strokeRoundedViewOffSlash
                          : HugeIcons.strokeRoundedView,
                      size: 20,
                      color: c.textSecondary,
                    ),
                    onPressed: isLoading
                        ? null
                        : () => setDialogState(
                              () => passwordObscure = !passwordObscure,
                            ),
                  ),
                ),
              ),
              if (fieldError != null) ...[
                const SizedBox(height: 8),
                Text(
                  fieldError!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isLoading ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: isLoading
                  ? null
                  : () {
                      if (confirmCtrl.text.trim() != 'ELIMINAR') {
                        setDialogState(() =>
                            fieldError = 'Escribí exactamente ELIMINAR.');
                        return;
                      }
                      if (passwordCtrl.text.trim().isEmpty) {
                        setDialogState(
                            () => fieldError = 'Ingresá tu contraseña.');
                        return;
                      }
                      setDialogState(() {
                        fieldError = null;
                        isLoading = true;
                      });
                      Navigator.pop(ctx, true);
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Eliminar cuenta'),
            ),
          ],
        ),
      ),
    );

    final password = passwordCtrl.text.trim();
    confirmCtrl.dispose();
    passwordCtrl.dispose();

    if (secondConfirmed != true || !mounted) return;

    // Mostrar loading en la pantalla mientras corre la request.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Eliminando cuenta...'),
            ],
          ),
          duration: Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final error = await ref
        .read(authNotifierProvider.notifier)
        .deleteAccount(password);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (error == null) {
      // Éxito — limpiar estado de providers y navegar a login.
      clearUserStateOnLogout(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tu cuenta fue eliminada correctamente.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // El router detectará state=null y redirigirá a login automáticamente.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    // Preferencias de notificación — cargadas desde el servidor con fallback a caché.
    final notifPrefsAsync = ref.watch(notificationPreferencesProvider);
    final notifPrefs = notifPrefsAsync.valueOrNull;
    final master = notifPrefs?.master ?? true;

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
          // ── CUENTA — header ──────────────────────────────────────
          if (user != null) ...[
            _AccountHeaderTile(user: user),
            const SizedBox(height: 24),
          ],

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

          // ── NOTIFICACIONES ────────────────────────────────────────
          _SectionHeader(title: 'NOTIFICACIONES'),
          _GroupContainer(
            children: [
              _SwitchTile(
                icon: HugeIcons.strokeRoundedNotification01,
                title: 'Notificaciones push',
                iconColor: AppColors.primary,
                value: master,
                onChanged: notifPrefs == null
                    ? null
                    : (v) => _saveNotifPref({'master': v}),
              ),
              _groupDivider(),
              _SwitchTile(
                icon: HugeIcons.strokeRoundedCalendarCheckIn01,
                title: 'Actividades',
                iconColor: master ? c.textSecondary : c.textTertiary,
                indent: true,
                value: master && (notifPrefs?.activities ?? true),
                // Deshabilitar (no solo ocultar) cuando master=false.
                onChanged: (notifPrefs == null || !master)
                    ? null
                    : (v) => _saveNotifPref({'activities': v}),
              ),
              _groupDivider(),
              _SwitchTile(
                icon: HugeIcons.strokeRoundedAward01,
                title: 'Logros',
                iconColor: master ? c.textSecondary : c.textTertiary,
                indent: true,
                value: master && (notifPrefs?.achievements ?? true),
                onChanged: (notifPrefs == null || !master)
                    ? null
                    : (v) => _saveNotifPref({'achievements': v}),
              ),
              _groupDivider(),
              _SwitchTile(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                title: 'Aprobaciones',
                iconColor: master ? c.textSecondary : c.textTertiary,
                indent: true,
                value: master && (notifPrefs?.approvals ?? true),
                onChanged: (notifPrefs == null || !master)
                    ? null
                    : (v) => _saveNotifPref({'approvals': v}),
              ),
              _groupDivider(),
              _SwitchTile(
                icon: HugeIcons.strokeRoundedUserAdd01,
                title: 'Invitaciones',
                iconColor: master ? c.textSecondary : c.textTertiary,
                indent: true,
                value: master && (notifPrefs?.invitations ?? true),
                onChanged: (notifPrefs == null || !master)
                    ? null
                    : (v) => _saveNotifPref({'invitations': v}),
              ),
              _groupDivider(),
              _SwitchTile(
                icon: HugeIcons.strokeRoundedClock01,
                title: 'Recordatorios',
                iconColor: master ? c.textSecondary : c.textTertiary,
                indent: true,
                value: master && (notifPrefs?.reminders ?? true),
                onChanged: (notifPrefs == null || !master)
                    ? null
                    : (v) => _saveNotifPref({'reminders': v}),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── CUENTA ────────────────────────────────────────────────
          _SectionHeader(title: 'CUENTA'),
          _GroupContainer(
            children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedQrCode,
                title: 'Mi credencial QR',
                iconColor: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MemberQrView(),
                  ),
                ),
              ),
              _groupDivider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedDeviceAccess,
                title: 'Sesiones activas',
                iconColor: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActiveSessionsView(),
                  ),
                ),
              ),
              _groupDivider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedDownload02,
                title: 'Descargar mis datos',
                iconColor: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DataExportView(),
                  ),
                ),
              ),
              _groupDivider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedLockPassword,
                title: 'Cambiar contraseña',
                iconColor: AppColors.primary,
                onTap: _showChangePasswordDialog,
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
                subtitle: _appVersion.isEmpty ? '—' : _appVersion,
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

          // ── SESIÓN ────────────────────────────────────────────────
          _GroupContainer(
            children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedLogout01,
                title: 'Cerrar sesión',
                iconColor: AppColors.error,
                onTap: _handleLogout,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── ZONA PELIGROSA ────────────────────────────────────────
          _GroupContainer(
            children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedDelete02,
                title: 'Eliminar cuenta',
                iconColor: AppColors.error,
                onTap: _handleDeleteAccount,
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

// ── Account header tile ───────────────────────────────────────────────────────

class _AccountHeaderTile extends StatelessWidget {
  final UserEntity user;

  const _AccountHeaderTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = user.name ?? '';
    final email = user.email;
    final avatar = user.avatar;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditProfileView()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight,
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar != null && avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _AvatarFallback(name: name),
                    )
                  : _AvatarFallback(name: name),
            ),
            const SizedBox(width: 14),
            // Name + email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: c.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;

  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── Switch tile ───────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final Color? iconColor;
  final bool value;
  final bool indent;
  /// null = toggle deshabilitado (usado cuando master=false).
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    this.iconColor,
    required this.value,
    required this.onChanged,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final effectiveIconColor = iconColor ?? c.textSecondary;
    final effectiveBg = iconColor != null
        ? iconColor!.withValues(alpha: 0.12)
        : c.surfaceVariant;

    return Padding(
      padding: EdgeInsets.only(
        left: indent ? 28 : 14,
        right: 14,
        top: 11,
        bottom: 11,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                color: effectiveIconColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

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

// ── Group container ───────────────────────────────────────────────────────────

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

// ── Theme picker dialog ───────────────────────────────────────────────────────

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

// ── Scale + fade entrance animation ──────────────────────────────────────────

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
