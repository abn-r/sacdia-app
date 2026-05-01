import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/ip_masker.dart';
import '../../../biometric/presentation/providers/biometric_provider.dart';
import '../../domain/entities/active_session.dart';
import '../providers/active_sessions_providers.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formatea un DateTime como tiempo relativo en español rioplatense.
///
/// Implementación local — no requiere paquete externo.
String _relativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return 'hace unos segundos';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return 'hace ${m == 1 ? '1 minuto' : '$m minutos'}';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'hace ${h == 1 ? '1 hora' : '$h horas'}';
  }
  if (diff.inDays < 30) {
    final d = diff.inDays;
    return 'hace ${d == 1 ? '1 día' : '$d días'}';
  }
  if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor();
    return 'hace ${months == 1 ? '1 mes' : '$months meses'}';
  }
  final years = (diff.inDays / 365).floor();
  return 'hace ${years == 1 ? '1 año' : '$years años'}';
}

/// Retorna el icono HugeIcons apropiado según el tipo de dispositivo.
HugeIconData _iconForDeviceType(SessionDeviceType type) {
  switch (type) {
    case SessionDeviceType.ios:
      return HugeIcons.strokeRoundedSmartPhone01;
    case SessionDeviceType.android:
      return HugeIcons.strokeRoundedSmartPhone02;
    case SessionDeviceType.web:
      return HugeIcons.strokeRoundedLaptop;
    case SessionDeviceType.unknown:
      return HugeIcons.strokeRoundedDeviceAccess;
  }
}

// ── View ──────────────────────────────────────────────────────────────────────

class ActiveSessionsView extends ConsumerStatefulWidget {
  const ActiveSessionsView({super.key});

  @override
  ConsumerState<ActiveSessionsView> createState() => _ActiveSessionsViewState();
}

class _ActiveSessionsViewState extends ConsumerState<ActiveSessionsView> {
  // IDs de sesiones en proceso de revocación (para loading state en el botón).
  final Set<String> _revokingIds = {};
  bool _revokingAll = false;

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.error : AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleRevoke(ActiveSession session) async {
    HapticFeedback.mediumImpact();

    setState(() => _revokingIds.add(session.sessionId));

    final error = await ref
        .read(activeSessionsProvider.notifier)
        .revoke(session.sessionId);

    if (!mounted) return;
    setState(() => _revokingIds.remove(session.sessionId));

    if (error != null) {
      _showSnackBar(error, isError: true);
    } else {
      _showSnackBar('profile.active_sessions.ui.revoked_ok'.tr());
    }
  }

  Future<void> _handleRevokeAll(List<ActiveSession> sessions) async {
    final otherCount = sessions.where((s) => !s.isCurrent).length;
    if (otherCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: context.sac.barrierColor,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text('profile.active_sessions.ui.dialog_close_others_title'.tr()),
        content: Text(
          otherCount == 1
              ? 'profile.active_sessions.ui.dialog_close_others_body_one'
                  .tr(namedArgs: {'count': '$otherCount'})
              : 'profile.active_sessions.ui.dialog_close_others_body_other'
                  .tr(namedArgs: {'count': '$otherCount'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('profile.active_sessions.ui.action_close_sessions'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Confirmación biométrica antes de revocar todas las otras sesiones
    // (no-op si el usuario no tiene biometría habilitada).
    final bioOk = await requireBiometricConfirmation(
      context,
      ref,
      reason: 'biometric.confirm_sensitive_action'.tr(),
    );
    if (!mounted) return;
    if (!bioOk) {
      _showSnackBar('profile.active_sessions.ui.operation_cancelled'.tr(), isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _revokingAll = true);

    final result = await ref
        .read(activeSessionsProvider.notifier)
        .revokeAllOthers();

    if (!mounted) return;
    setState(() => _revokingAll = false);

    if (result.error != null) {
      _showSnackBar(result.error!, isError: true);
    } else {
      final n = result.count;
      _showSnackBar(
        n == 1
            ? 'profile.active_sessions.ui.revoked_all_one'.tr()
            : 'profile.active_sessions.ui.revoked_all_other'.tr(namedArgs: {'count': '$n'}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        title: Text('profile.active_sessions.ui.title'.tr()),
        backgroundColor: c.surfaceVariant,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: sessionsAsync.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.read(activeSessionsProvider.notifier).refresh(),
        ),
        data: (sessions) => sessions.isEmpty
            ? const _EmptyState()
            : _SessionList(
                sessions: sessions,
                revokingIds: _revokingIds,
                isRevokingAll: _revokingAll,
                onRevoke: _handleRevoke,
                onRevokeAll: () => _handleRevokeAll(sessions),
                onRefresh: () =>
                    ref.read(activeSessionsProvider.notifier).refresh(),
              ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedWifiError01,
              size: 48,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 16,
                color: Colors.white,
              ),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedDeviceAccess,
              size: 48,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'profile.active_sessions.ui.no_sessions'.tr(),
              style: TextStyle(fontSize: 15, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session list ──────────────────────────────────────────────────────────────

class _SessionList extends StatelessWidget {
  final List<ActiveSession> sessions;
  final Set<String> revokingIds;
  final bool isRevokingAll;
  final void Function(ActiveSession) onRevoke;
  final VoidCallback onRevokeAll;
  final Future<void> Function() onRefresh;

  const _SessionList({
    required this.sessions,
    required this.revokingIds,
    required this.isRevokingAll,
    required this.onRevoke,
    required this.onRevokeAll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasOtherSessions = sessions.any((s) => !s.isCurrent);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Cabecera informativa
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'profile.active_sessions.ui.devices_header'.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.sac.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Lista de sesiones en un contenedor agrupado
          _GroupContainer(
            children: List.generate(sessions.length * 2 - 1, (i) {
              if (i.isOdd) return _groupDivider(context);
              final session = sessions[i ~/ 2];
              return _SessionCard(
                session: session,
                isRevoking: revokingIds.contains(session.sessionId),
                onRevoke: () => onRevoke(session),
              );
            }),
          ),

          // Botón "Cerrar sesión en todos los otros dispositivos"
          if (hasOtherSessions) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isRevokingAll ? null : onRevokeAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isRevokingAll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : HugeIcon(
                        icon: HugeIcons.strokeRoundedLogout01,
                        size: 18,
                        color: AppColors.error,
                      ),
                label: Text(
                  isRevokingAll
                      ? 'profile.active_sessions.ui.closing_sessions'.tr()
                      : 'profile.active_sessions.ui.close_all_others'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _groupDivider(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 62,
        color: context.sac.borderLight,
      );
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final ActiveSession session;
  final bool isRevoking;
  final VoidCallback onRevoke;

  const _SessionCard({
    required this.session,
    required this.isRevoking,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final icon = _iconForDeviceType(session.deviceType);
    final iconColor =
        session.isCurrent ? AppColors.secondary : c.textSecondary;
    final iconBg = iconColor.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icono del dispositivo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                size: 19,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Detalles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  session.isCurrent
                      ? 'profile.active_sessions.ui.this_session'.tr()
                      : maskIpAddress(session.ipAddress),
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'profile.active_sessions.ui.last_used'.tr(namedArgs: {'time': _relativeTime(session.lastActiveAt)}),
                  style: TextStyle(fontSize: 11, color: c.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Trailing: badge "Activa" o botón de revocar
          if (session.isCurrent)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'profile.active_sessions.ui.session_active_badge'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            )
          else
            _RevokeButton(
              isRevoking: isRevoking,
              onRevoke: onRevoke,
            ),
        ],
      ),
    );
  }
}

// ── Revoke button ─────────────────────────────────────────────────────────────

class _RevokeButton extends StatelessWidget {
  final bool isRevoking;
  final VoidCallback onRevoke;

  const _RevokeButton({required this.isRevoking, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    if (isRevoking) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.error,
        ),
      );
    }

    return GestureDetector(
      onTap: onRevoke,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedDelete02,
            size: 16,
            color: AppColors.error,
          ),
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
