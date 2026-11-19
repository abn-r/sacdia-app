import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../profile/domain/entities/notification_preferences.dart';
import '../../../profile/presentation/providers/notification_preferences_providers.dart';
import '../providers/notification_permission_provider.dart';
import '../widgets/notification_permission_card.dart';

/// Notification settings: one master switch and, under it, the five kinds of
/// alert with a line that says what each one covers.
///
/// With the master off the kinds fold away and a note says what keeps
/// arriving. If the phone denied notifications for the app, a card explains it
/// and the kinds are disabled (the phone decides, not the app).
class NotificationSettingsView extends ConsumerStatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  ConsumerState<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState
    extends ConsumerState<NotificationSettingsView>
    with WidgetsBindingObserver {
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The user may come back from the phone settings with a new permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final denied =
        await ref.read(notificationPermissionGateProvider).isDenied();
    if (!mounted || denied == _permissionDenied) return;
    setState(() => _permissionDenied = denied);
  }

  /// Optimistic update; the notifier reverts it if the server refuses.
  Future<void> _save(Map<String, bool> delta) async {
    final error =
        await ref.read(notificationPreferencesProvider.notifier).patch(delta);
    if (error != null && mounted) {
      SacSnackBar.show(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final prefs = ref.watch(notificationPreferencesProvider).value;
    // Derived from the categories, not `master`: the backend reports
    // master=false as soon as any one category is off.
    final master = prefs?.anyCategoryEnabled ?? true;
    final canEdit = prefs != null && !_permissionDenied;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'settings.notifications_title'.tr(),
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
                if (_permissionDenied) ...[
                  NotificationPermissionCard(
                    onOpenSettings: () => ref
                        .read(notificationPermissionGateProvider)
                        .openSettings(),
                  ),
                  const SizedBox(height: 24),
                ],
                SacSettingsGroup(
                  children: [
                    SacSettingsSwitchTile(
                      key: const ValueKey('notif-master'),
                      icon: HugeIcons.strokeRoundedNotification01,
                      title: 'settings.notifications.allow_title'.tr(),
                      subtitle: 'settings.notifications.allow_subtitle'.tr(),
                      value: master,
                      onChanged:
                          prefs == null ? null : (v) => _save({'master': v}),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Collapsible(
                  show: master,
                  child: _KindsGroup(
                    prefs: prefs,
                    enabled: canEdit,
                    onChanged: _save,
                  ),
                ),
                _Collapsible(
                  show: !master,
                  child: SacSettingsFooter(
                    'settings.notifications.off_note'.tr(),
                  ),
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

/// Folds [child] away (height and opacity together) when [show] is false.
/// Instant under reduced motion. Nothing stays in the tree once folded.
class _Collapsible extends StatelessWidget {
  const _Collapsible({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = SacMotion.reduceMotionOf(context)
        ? Duration.zero
        : SacMotion.routeEnter;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: show ? 1 : 0),
      duration: duration,
      curve: SacMotion.easeOut,
      child: child,
      builder: (context, t, child) {
        if (t == 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
    );
  }
}

class _Kind {
  const _Kind(this.key, this.icon, this.titleKey, this.descKey, this.read);

  final String key;
  final HugeIconData icon;
  final String titleKey;
  final String descKey;
  final bool Function(NotificationPreferences) read;
}

final _kinds = <_Kind>[
  _Kind(
    'activities',
    HugeIcons.strokeRoundedCalendarCheckIn01,
    'profile.settings.notif_activities',
    'settings.notifications.activities_desc',
    (p) => p.activities,
  ),
  _Kind(
    'achievements',
    HugeIcons.strokeRoundedChampion,
    'profile.settings.notif_achievements',
    'settings.notifications.achievements_desc',
    (p) => p.achievements,
  ),
  _Kind(
    'approvals',
    HugeIcons.strokeRoundedCheckmarkCircle01,
    'profile.settings.notif_approvals',
    'settings.notifications.approvals_desc',
    (p) => p.approvals,
  ),
  _Kind(
    'invitations',
    HugeIcons.strokeRoundedUserAdd01,
    'profile.settings.notif_invitations',
    'settings.notifications.invitations_desc',
    (p) => p.invitations,
  ),
  _Kind(
    'reminders',
    HugeIcons.strokeRoundedClock01,
    'profile.settings.notif_reminders',
    'settings.notifications.reminders_desc',
    (p) => p.reminders,
  ),
];

class _KindsGroup extends StatelessWidget {
  const _KindsGroup({
    required this.prefs,
    required this.enabled,
    required this.onChanged,
  });

  final NotificationPreferences? prefs;
  final bool enabled;
  final ValueChanged<Map<String, bool>> onChanged;

  @override
  Widget build(BuildContext context) {
    return SacSettingsGroup(
      title: 'settings.notifications.section_types'.tr().toUpperCase(),
      children: [
        for (var i = 0; i < _kinds.length; i++) ...[
          if (i > 0) const SacSettingsDivider(),
          SacSettingsSwitchTile(
            key: ValueKey('notif-${_kinds[i].key}'),
            icon: _kinds[i].icon,
            title: _kinds[i].titleKey.tr(),
            subtitle: _kinds[i].descKey.tr(),
            muted: !enabled,
            value: prefs == null ? true : _kinds[i].read(prefs!),
            onChanged: enabled ? (v) => onChanged({_kinds[i].key: v}) : null,
          ),
        ],
      ],
    );
  }
}
