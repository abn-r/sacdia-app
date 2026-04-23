import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/realtime/realtime_ref.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../profile/presentation/widgets/setting_tile.dart';
import '../providers/sync_cache_providers.dart';
import 'clear_cache_dialog.dart';

/// Drop-in Settings section with the 3 sync/cache tiles:
///   1. Limpiar caché — shows total size; menu picks images-only vs all.
///   2. Forzar sincronización — invalidates providers + updates timestamp.
///   3. Última sincronización — relative-time display of last success.
///
/// Export-ready: the Settings view imports this widget and drops it
/// between its existing grouped sections. Self-contained — no params.
class SyncCacheSection extends ConsumerWidget {
  const SyncCacheSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(cacheInfoProvider);
    final syncState = ref.watch(syncControllerProvider);
    final clearState = ref.watch(clearCacheControllerProvider);

    final c = context.sac;

    final info = infoAsync.valueOrNull;
    final sizeLabel = info == null
        ? '—'
        : formatBytes(info.totalBytes);
    final lastSyncLabel = info == null
        ? '—'
        : formatRelativeTime(info.lastSyncAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: 'settings.section_sync'.tr()),
        _GroupContainer(
          children: [
            // ── Tile 1: Limpiar caché ────────────────────────────────────
            SettingTile(
              icon: HugeIcons.strokeRoundedDatabase01,
              title: 'settings.clear_cache_tile'.tr(),
              subtitle:
                  '${'settings.cache_size_label'.tr()}: $sizeLabel',
              iconColor: AppColors.primary,
              trailing: clearState.inProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: clearState.inProgress
                  ? null
                  : () => _showClearMenu(context, ref),
            ),
            _Divider(color: c.borderLight),
            // ── Tile 2: Forzar sincronización ────────────────────────────
            SettingTile(
              icon: HugeIcons.strokeRoundedRefresh,
              title: 'settings.force_sync_tile'.tr(),
              subtitle: syncState.inProgress
                  ? 'settings.force_sync_in_progress'.tr()
                  : null,
              iconColor: AppColors.primary,
              trailing: syncState.inProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: syncState.inProgress
                  ? null
                  : () => _runSync(context, ref),
            ),
            _Divider(color: c.borderLight),
            // ── Tile 3: Última sincronización ────────────────────────────
            SettingTile(
              icon: HugeIcons.strokeRoundedClock01,
              title: 'settings.last_sync_label'.tr(),
              subtitle: lastSyncLabel,
              iconColor: c.textSecondary,
            ),
          ],
        ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _showClearMenu(BuildContext context, WidgetRef ref) async {
    final c = context.sac;
    final mode = await showModalBottomSheet<ClearCacheMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 8,
          right: 8,
          bottom: 12 + MediaQuery.of(sheetCtx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                color: AppColors.primary,
              ),
              title: Text('settings.clear_cache_images_only'.tr()),
              onTap: () => Navigator.pop(sheetCtx, ClearCacheMode.imagesOnly),
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
              ),
              title: Text(
                'settings.clear_cache_all_data'.tr(),
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.pop(sheetCtx, ClearCacheMode.allData),
            ),
          ],
        ),
      ),
    );

    if (mode == null || !context.mounted) return;

    // Destructive variant needs a second confirmation.
    if (mode == ClearCacheMode.allData) {
      final confirmed = await showClearCacheConfirmDialog(context);
      if (confirmed != true || !context.mounted) return;
    }

    final ok = await ref.read(clearCacheControllerProvider.notifier).run(mode);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'settings.clear_cache_success'.tr()
              : 'settings.clear_cache_error'.tr(),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(syncControllerProvider.notifier)
        .run(RealtimeRef.fromWidgetRef(ref));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'settings.force_sync_success'.tr()
              : (result.errorMessage ?? 'settings.force_sync_error'.tr()),
        ),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Private layout primitives (match settings_view.dart style) ───────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 0),
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

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, indent: 60, color: color);
  }
}
