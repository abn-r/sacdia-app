import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/theme_provider.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../qr/presentation/views/qr_scanner_view.dart';
import '../../../settings/presentation/providers/app_version_provider.dart';
import '../../../settings/presentation/views/about_view.dart';
import '../../../settings/presentation/views/appearance_view.dart';
import '../../../settings/presentation/views/notification_settings_view.dart';
import '../../../settings/presentation/widgets/language_picker_tile.dart';
import '../../../support/presentation/views/support_view.dart';
import '../../../transfers/presentation/views/transfer_requests_view.dart';
import '../../../virtual_card/presentation/views/virtual_card_view.dart';
import '../../domain/entities/notification_preferences.dart';
import '../providers/notification_preferences_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/settings_identity_row.dart';
import 'edit_profile_view.dart';
import 'my_data_view.dart';
import 'security_view.dart';

/// Settings index: identity, then one row per topic. Each topic opens its own
/// screen (appearance, notifications, about...), so this page stays short.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  static void _push(BuildContext context, Widget page) {
    Navigator.push(context, SacSharedAxisRoute(builder: (_) => page));
  }

  /// "Todas" / "Algunas" / "Apagadas" from the stored preferences.
  static String _notificationsValue(NotificationPreferences? prefs) {
    if (prefs == null) return 'settings.notif_value_all'.tr();
    final on = [
      prefs.activities,
      prefs.achievements,
      prefs.approvals,
      prefs.invitations,
      prefs.reminders,
    ].where((v) => v).length;
    if (on == 5) return 'settings.notif_value_all'.tr();
    if (on == 0) return 'settings.notif_value_off'.tr();
    return 'settings.notif_value_some'.tr();
  }

  static String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'profile.settings.theme_light'.tr(),
        ThemeMode.dark => 'profile.settings.theme_dark'.tr(),
        ThemeMode.system => 'profile.settings.theme_system'.tr(),
      };

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await SacDialog.show(
      context,
      title: 'profile.settings.logout_tile'.tr(),
      content: 'profile.settings.logout_confirm'.tr(),
      confirmLabel: 'profile.settings.logout_confirm_action'.tr(),
      confirmIsDestructive: true,
    );

    if (shouldLogout == true && context.mounted) {
      final success = await ref.read(authNotifierProvider.notifier).signOut();
      if (success && context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final UserEntity? user = ref.watch(
      authNotifierProvider.select((v) => v.value),
    );
    // Mientras se actúa por un menor no se ofrecen contraseña, sesiones,
    // exportación de datos ni borrado de cuenta: son del tutor (FP-56).
    final acting = ref.watch(actingDependentProvider) != null;
    // Un adolescente supervisado no ve sesiones, exportación de datos, borrado
    // de cuenta ni cambio de club: son del tutor (FP3-32; el cambio de club lo
    // gestiona el tutor y el servidor lo niega). SÍ puede cambiar su contraseña.
    final teen = user?.isLimitedAccount ?? false;
    final prefs = ref.watch(notificationPreferencesProvider).value;
    final appInfo = ref.watch(appPackageInfoProvider).value;
    // Full name when the profile is loaded; the account name until then.
    final fullName = ref.watch(
      profileNotifierProvider.select((v) => v.value?.fullName),
    );

    // «Seguridad» siempre tiene contenido (el desbloqueo biométrico es de este
    // teléfono); dentro, la contraseña y las sesiones siguen sus propias
    // reglas. «Mis datos» (copia de datos y borrado de cuenta) es del tutor.
    final showMyData = !acting && !teen;
    // Mismo gate que el escaneo de asistencia: sin permiso ni capacidad, la
    // directiva no aparece.
    final canScan = hasAnyPermission(user, const {'attendance:manage'}) ||
        hasCapability(user, 'club.operational_staff');

    final c = context.sac;

    String upper(String key) => key.tr().toUpperCase();

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
                if (user != null) ...[
                  SettingsIdentityRow(
                    key: const ValueKey('settings-identity'),
                    name: (fullName != null && fullName.isNotEmpty)
                        ? fullName
                        : (user.name ?? ''),
                    email: user.email ?? '',
                    avatarUrl: user.avatar,
                    onTap: () => _push(context, const EditProfileView()),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── MI CLUB ───────────────────────────────────────────────
                SacSettingsGroup(
                  title: upper('settings.section_my_club'),
                  children: [
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedQrCode,
                      title: 'settings.member_qr'.tr(),
                      onTap: () => _push(context, const VirtualCardView()),
                    ),
                    // Mi familia lives here for everyone (most users have no
                    // minors); the profile shows it only to guardians.
                    if (!acting && !teen) ...[
                      const SacSettingsDivider(),
                      SacSettingsTile(
                        key: const ValueKey('settings-family'),
                        icon: HugeIcons.strokeRoundedUserGroup,
                        title: 'family.profile.entry_title'.tr(),
                        subtitle: (user?.family?.dependentsCount ?? 0) > 0
                            ? 'family.profile.entry_count'.plural(
                                user!.family!.dependentsCount,
                                name: 'count',
                              )
                            : 'settings.family_subtitle'.tr(),
                        onTap: () => context.push(RouteNames.family),
                      ),
                    ],
                    if (!teen) ...[
                      const SacSettingsDivider(),
                      SacSettingsTile(
                        icon: HugeIcons.strokeRoundedExchange01,
                        title: 'profile.settings.change_club_tile'.tr(),
                        // «Mis solicitudes»: muestra la pendiente (si hay) y
                        // desde ahí se crea una nueva. Ir directo al
                        // formulario ocultaba la solicitud en trámite.
                        onTap: () =>
                            _push(context, const TransferRequestsView()),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // ── PREFERENCIAS ──────────────────────────────────────────
                SacSettingsGroup(
                  title: upper('settings.section_preferences'),
                  children: [
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedPaintBrush01,
                      title: 'settings.appearance_title'.tr(),
                      value: _themeName(themeMode),
                      onTap: () => _push(context, const AppearanceView()),
                    ),
                    const SacSettingsDivider(),
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedNotification01,
                      title: 'settings.notifications_title'.tr(),
                      value: _notificationsValue(prefs),
                      onTap: () =>
                          _push(context, const NotificationSettingsView()),
                    ),
                    const SacSettingsDivider(),
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedGlobe02,
                      title: 'settings.language_picker_title'.tr(),
                      value: LanguagePickerTile.labelOf(context.locale),
                      onTap: () => LanguagePickerTile.showPicker(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── SEGURIDAD Y PRIVACIDAD ────────────────────────────────
                SacSettingsGroup(
                  title: upper('settings.section_security_privacy'),
                  children: [
                    SacSettingsTile(
                      key: const ValueKey('settings-security'),
                      icon: HugeIcons.strokeRoundedSecurityLock,
                      title: 'settings.security_title'.tr(),
                      onTap: () => _push(context, const SecurityView()),
                    ),
                    if (showMyData) ...[
                      const SacSettingsDivider(),
                      SacSettingsTile(
                        key: const ValueKey('settings-my-data'),
                        icon: HugeIcons.strokeRoundedDatabase01,
                        title: 'settings.my_data_title'.tr(),
                        subtitle: 'settings.my_data_subtitle'.tr(),
                        onTap: () => _push(context, const MyDataView()),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // ── DIRECTIVA ─────────────────────────────────────────────
                if (canScan) ...[
                  SacSettingsGroup(
                    title: upper('settings.section_directive'),
                    children: [
                      SacSettingsTile(
                        key: const ValueKey('settings-scan'),
                        icon: HugeIcons.strokeRoundedQrCode01,
                        title: 'settings.scan_qr'.tr(),
                        onTap: () => _push(context, const QrScannerView()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // ── AYUDA ─────────────────────────────────────────────────
                SacSettingsGroup(
                  title: upper('settings.section_help'),
                  children: [
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedHelpCircle,
                      title: 'support.settings_entry_title'.tr(),
                      onTap: () => context.push(SupportView.routeName),
                    ),
                    const SacSettingsDivider(),
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      title: 'settings.about_title'.tr(),
                      value: appInfo?.version,
                      onTap: () => _push(context, const AboutView()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── SESIÓN ────────────────────────────────────────────────
                SacSettingsGroup(
                  children: [
                    SacSettingsTile(
                      icon: HugeIcons.strokeRoundedLogout02,
                      title: 'profile.settings.logout_tile'.tr(),
                      destructive: true,
                      onTap: () => _handleLogout(context, ref),
                    ),
                  ],
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            );
          },
        ),
      ),
    );
  }
}
