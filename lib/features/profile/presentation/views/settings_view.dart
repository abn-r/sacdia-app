import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/in_app_browser.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/accent_provider.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/zarza_roja_credit.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../auth/domain/entities/user_entity.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/notification_preferences_providers.dart';
import '../widgets/accent_picker_sheet.dart';
import '../utils/change_password_flow.dart';
import '../utils/run_delete_account_flow.dart';
import '../widgets/setting_tile.dart';
import '../../../qr/presentation/views/qr_scanner_view.dart';
import '../../../accessibility/presentation/widgets/accessibility_settings_section.dart';
import '../../../biometric/presentation/widgets/biometric_settings_section.dart';
import '../../../settings/presentation/widgets/language_picker_tile.dart';
import '../../../settings/presentation/widgets/sync_cache_section.dart';
import '../../../support/presentation/widgets/support_settings_section.dart';
import '../../../transfers/presentation/views/transfer_requests_view.dart';
import '../../../virtual_card/presentation/views/virtual_card_view.dart';
import 'active_sessions_view.dart';
import 'data_export_view.dart';
import 'edit_profile_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';

const Set<String> _attendanceScannerRoles = {
  ClubRoleNames.director,
  ClubRoleNames.deputyDirector,
  ClubRoleNames.secretary,
  ClubRoleNames.treasurer,
  ClubRoleNames.secretaryTreasurer,
  ClubRoleNames.counselor,
};

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

  Future<void> _openLegalDocument(String url) async {
    final opened = await openInAppDocument(Uri.parse(url));
    if (!opened && mounted) {
      SacSnackBar.show(context, 'settings.open_document_failed'.tr());
    }
  }

  /// Aplica un cambio de preferencia con optimistic update.
  ///
  /// Llama PATCH /users/me/notification-preferences con el delta.
  /// Revierte automáticamente si el backend falla y muestra snackbar de error.
  Future<void> _saveNotifPref(Map<String, bool> delta) async {
    final error =
        await ref.read(notificationPreferencesProvider.notifier).patch(delta);

    if (error != null && mounted) {
      SacSnackBar.show(context, error, isError: true);
    }
  }

  Future<void> _showChangePasswordDialog() =>
      runChangePasswordFlow(context, ref);

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
        return 'profile.settings.theme_light'.tr();
      case ThemeMode.dark:
        return 'profile.settings.theme_dark'.tr();
      case ThemeMode.system:
        return 'profile.settings.theme_system'.tr();
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await SacDialog.show(
      context,
      title: 'profile.settings.logout_tile'.tr(),
      content: 'profile.settings.logout_confirm'.tr(),
      confirmLabel: 'profile.settings.logout_confirm_action'.tr(),
      confirmIsDestructive: true,
    );

    if (shouldLogout == true && mounted) {
      final success = await ref.read(authNotifierProvider.notifier).signOut();
      if (success && mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleDeleteAccount() => runDeleteAccountFlow(context, ref);

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final accent = ref.watch(accentNotifierProvider);
    final user = ref.watch(
      authNotifierProvider.select((v) => v.valueOrNull),
    );
    // Mientras se actúa por un menor no se ofrecen seguridad, sesiones,
    // exportación de datos ni borrado de cuenta: son del tutor (FP-56).
    final acting = ref.watch(actingDependentProvider) != null;
    // Un adolescente supervisado no ve sesiones, exportación de datos, borrado
    // de cuenta ni cambio de club: son del tutor (FP3-32; el cambio de club lo
    // gestiona el tutor y el servidor lo niega). SÍ puede cambiar su contraseña.
    final teen = user?.isLimitedAccount ?? false;
    // Preferencias de notificación — cargadas desde el servidor con fallback a caché.
    final notifPrefsAsync = ref.watch(notificationPreferencesProvider);
    final notifPrefs = notifPrefsAsync.valueOrNull;
    // Derived from the categories, not `master`: the backend reports
    // master=false as soon as any one category is off.
    final master = notifPrefs?.anyCategoryEnabled ?? true;

    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'settings.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final bar = SacTopBar.frostedInset(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(16, bar + 8, 16, 8),
              children: [
                // ── CUENTA — header ──────────────────────────────────────
                if (user != null) ...[
                  _AccountHeaderTile(user: user),
                  const SizedBox(height: 24),
                ],

                // ── APARIENCIA ────────────────────────────────────────────
                _SectionHeader(title: 'settings.section_appearance'.tr()),
                _GroupContainer(
                  children: [
                    SettingTile(
                      icon: HugeIcons.strokeRoundedPaintBrush01,
                      title: 'profile.settings.theme_title'.tr(),
                      subtitle: _getThemeName(themeMode),
                      iconColor: SacAccent.of(context).color,
                      onTap: _showThemeDialog,
                    ),
                    _groupDivider(),
                    SettingTile(
                      icon: HugeIcons.strokeRoundedColors,
                      title: 'profile.settings.accent_title'.tr(),
                      subtitle: accent.labelKey.tr(),
                      iconColor: SacAccent.of(context).color,
                      onTap: () => showAccentPicker(context, ref),
                    ),
                    _groupDivider(),
                    const AccessibilitySettingsSection(),
                  ],
                ),
                const SizedBox(height: 24),

                // ── NOTIFICACIONES ────────────────────────────────────────
                _SectionHeader(title: 'settings.section_notifications'.tr()),
                _GroupContainer(
                  children: [
                    _SwitchTile(
                      icon: HugeIcons.strokeRoundedNotification01,
                      title: 'profile.settings.notif_push'.tr(),
                      iconColor: SacAccent.of(context).color,
                      value: master,
                      onChanged: notifPrefs == null
                          ? null
                          : (v) => _saveNotifPref({'master': v}),
                    ),
                    _groupDivider(),
                    _SwitchTile(
                      icon: HugeIcons.strokeRoundedCalendarCheckIn01,
                      title: 'profile.settings.notif_activities'.tr(),
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
                      icon: HugeIcons.strokeRoundedChampion,
                      title: 'profile.settings.notif_achievements'.tr(),
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
                      title: 'profile.settings.notif_approvals'.tr(),
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
                      title: 'profile.settings.notif_invitations'.tr(),
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
                      title: 'profile.settings.notif_reminders'.tr(),
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

                // ── AYUDA Y SOPORTE ───────────────────────────────────────
                const SupportSettingsSection(),
                const SizedBox(height: 24),

                // ── SINCRONIZACIÓN / CACHÉ ────────────────────────────────
                const SyncCacheSection(),
                const SizedBox(height: 24),

                // ── CUENTA ────────────────────────────────────────────────
                _SectionHeader(title: 'settings.section_account'.tr()),
                _GroupContainer(
                  children: [
                    SettingTile(
                      icon: HugeIcons.strokeRoundedQrCode,
                      title: 'settings.member_qr'.tr(),
                      iconColor: SacAccent.of(context).color,
                      onTap: () => Navigator.push(
                        context,
                        SacSharedAxisRoute(
                          builder: (_) => const VirtualCardView(),
                        ),
                      ),
                    ),
                    if (!teen) ...[
                      _groupDivider(),
                      SettingTile(
                        icon: HugeIcons.strokeRoundedExchange01,
                        title: 'profile.settings.change_club_tile'.tr(),
                        subtitle: 'profile.settings.change_club_subtitle'.tr(),
                        iconColor: SacAccent.of(context).color,
                        onTap: () => Navigator.push(
                          context,
                          SacSharedAxisRoute(
                            // «Mis solicitudes»: muestra la pendiente (si hay)
                            // y desde ahí se crea una nueva. Ir directo al
                            // formulario ocultaba la solicitud en trámite.
                            builder: (_) => const TransferRequestsView(),
                          ),
                        ),
                      ),
                    ],
                    if (hasAnyPermission(user, const {'attendance:manage'}) ||
                        hasAnyRole(user, _attendanceScannerRoles)) ...[
                      _groupDivider(),
                      SettingTile(
                        icon: HugeIcons.strokeRoundedQrCode01,
                        title: 'settings.scan_qr'.tr(),
                        iconColor: SacAccent.of(context).color,
                        onTap: () => Navigator.push(
                          context,
                          SacSharedAxisRoute(
                            builder: (_) => const QrScannerView(),
                          ),
                        ),
                      ),
                    ],
                    if (!acting && !teen) ...[
                      _groupDivider(),
                      SettingTile(
                        icon: HugeIcons.strokeRoundedDeviceAccess,
                        title: 'settings.active_sessions'.tr(),
                        iconColor: SacAccent.of(context).color,
                        onTap: () => Navigator.push(
                          context,
                          SacSharedAxisRoute(
                            builder: (_) => const ActiveSessionsView(),
                          ),
                        ),
                      ),
                      _groupDivider(),
                      SettingTile(
                        icon: HugeIcons.strokeRoundedDownload02,
                        title: 'settings.download_my_data'.tr(),
                        iconColor: SacAccent.of(context).color,
                        onTap: () => Navigator.push(
                          context,
                          SacSharedAxisRoute(
                            builder: (_) => const DataExportView(),
                          ),
                        ),
                      ),
                    ],
                    if (!acting) ...[
                      _groupDivider(),
                      SettingTile(
                        icon: HugeIcons.strokeRoundedLockPassword,
                        title: 'settings.change_password'.tr(),
                        iconColor: SacAccent.of(context).color,
                        onTap: _showChangePasswordDialog,
                      ),
                    ],
                    _groupDivider(),
                    const BiometricSettingsSection(),
                    _groupDivider(),
                    const LanguagePickerTile(),
                  ],
                ),
                const SizedBox(height: 24),

                // ── ACERCA DE ─────────────────────────────────────────────
                _SectionHeader(title: 'settings.section_about'.tr()),
                _GroupContainer(
                  children: [
                    SettingTile(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      title: 'profile.settings.about_version'.tr(),
                      subtitle: _appVersion.isEmpty ? '—' : _appVersion,
                    ),
                    _groupDivider(),
                    SettingTile(
                      icon: HugeIcons.strokeRoundedSecurityCheck,
                      title: 'profile.settings.privacy_policy'.tr(),
                      onTap: () =>
                          _openLegalDocument(AppConstants.privacyPolicyUrl),
                    ),
                    _groupDivider(),
                    SettingTile(
                      icon: HugeIcons.strokeRoundedLegalDocument01,
                      title: 'profile.settings.terms'.tr(),
                      onTap: () => _openLegalDocument(AppConstants.termsUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── SESIÓN ────────────────────────────────────────────────
                _GroupContainer(
                  children: [
                    SettingTile(
                      icon: HugeIcons.strokeRoundedLogout02,
                      title: 'profile.settings.logout_tile'.tr(),
                      iconColor: AppColors.error,
                      onTap: _handleLogout,
                    ),
                  ],
                ),
                if (!acting && !teen) ...[
                  const SizedBox(height: 16),

                  // ── ZONA PELIGROSA ──────────────────────────────────────
                  _GroupContainer(
                    children: [
                      SettingTile(
                        icon: HugeIcons.strokeRoundedDelete02,
                        title: 'profile.settings.delete_account_tile'.tr(),
                        iconColor: AppColors.error,
                        onTap: _handleDeleteAccount,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                const ZarzaRojaCredit(),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            );
          },
        ),
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
    final email = user.email ?? '';
    final avatar = user.avatar;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          SacSharedAxisRoute(builder: (_) => const EditProfileView()),
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
                color: SacAccent.of(context).light,
              ),
              clipBehavior: Clip.antiAlias,
              child: avatar != null && avatar.isNotEmpty
                  ? SacProfileImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      memCacheWidth: 156,
                      memCacheHeight: 156,
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
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: SacAccent.of(context).color,
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
          SacPressable(
            listenOnly: true,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: SacAccent.of(context).color,
              activeTrackColor:
                  SacAccent.of(context).color.withValues(alpha: 0.4),
            ),
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
      (
        ThemeMode.light,
        'profile.settings.theme_light'.tr(),
        HugeIcons.strokeRoundedSun01
      ),
      (
        ThemeMode.dark,
        'profile.settings.theme_dark'.tr(),
        HugeIcons.strokeRoundedMoon01
      ),
      (
        ThemeMode.system,
        'profile.settings.theme_system'.tr(),
        HugeIcons.strokeRoundedSmartPhone01
      ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Text(
                  'profile.settings.select_theme_title'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: SacAccent.of(context).color,
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
                    SacInkWell(
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
                                  ? SacAccent.of(context).color
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
                                      ? SacAccent.of(context).color
                                      : c.textSecondary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedTick02,
                                size: 18,
                                color: SacAccent.of(context).color,
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
              SacPressable(
                listenOnly: true,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: (TextButton.styleFrom(
                    foregroundColor: c.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 0),
                    shape: const RoundedRectangleBorder(),
                  )).copyWith(enableFeedback: false),
                  child: Text(
                    'common.cancel'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: c.textSecondary,
                    ),
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
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
    );
    _scale = CurvedAnimation(parent: _controller, curve: SacMotion.easeOut)
        .drive(Tween<double>(begin: SacMotion.enterScale, end: 1.0));
    _fade = CurvedAnimation(parent: _controller, curve: SacMotion.easeOut)
        .drive(Tween<double>(begin: 0.0, end: 1.0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (SacMotion.reduceMotionOf(context)) {
      _controller.duration = SacMotion.reducedFade;
    }
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
        child: ScaleTransition(
          scale: SacMotion.reduceMotionOf(context)
              ? const AlwaysStoppedAnimation(1)
              : _scale,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
