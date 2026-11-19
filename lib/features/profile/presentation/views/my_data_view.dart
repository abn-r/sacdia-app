import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:share_plus/share_plus.dart';

import '../../../biometric/presentation/providers/biometric_provider.dart';
import '../../domain/entities/data_export.dart';
import '../providers/data_export_providers.dart';
import '../utils/run_delete_account_flow.dart';
import '../widgets/delete_account_consequences_sheet.dart';
import '../widgets/my_data_state_panel.dart';

/// Mis datos: the state of your data copy, the copies you asked for and, at
/// the end, "Eliminar mi cuenta" (which first shows what is lost).
///
/// One panel shows only the CURRENT state of the copy and fades when it
/// changes. The request button is pinned at the bottom; while the 24 h cooldown
/// is on it is disabled and a note says when the next copy opens.
class MyDataView extends ConsumerStatefulWidget {
  const MyDataView({
    super.key,
    @visibleForTesting this.deleteAccountRunner = runDeleteAccountFlow,
  });

  /// The delete-account flow; replaced in tests.
  final DeleteAccountRunner deleteAccountRunner;

  @override
  ConsumerState<MyDataView> createState() => _MyDataViewState();
}

class _MyDataViewState extends ConsumerState<MyDataView> {
  final _scroll = ScrollController();
  bool _isRequesting = false;
  final Set<String> _downloadingIds = {};
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  /// Polls every 10 s while a copy is being prepared.
  void _startPollingIfNeeded(List<DataExport> exports) {
    final hasInProgress = exports.any((e) => e.isInProgress);

    if (hasInProgress && _pollingTimer == null) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _poll();
      });
    } else if (!hasInProgress && _pollingTimer != null) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> _poll() async {
    await ref.read(dataExportProvider.notifier).refresh();
    if (!mounted) return;
    final current = ref.read(dataExportProvider).value ?? [];
    if (!current.any((e) => e.isInProgress)) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    SacSnackBar.show(context, message, isError: isError);
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _handleRequestExport() async {
    HapticFeedback.mediumImpact();

    // Biometric confirmation (no-op when biometrics are off).
    final bioOk = await requireBiometricConfirmation(
      context,
      ref,
      reason: 'biometric.confirm_sensitive_action'.tr(),
    );
    if (!mounted) return;
    if (!bioOk) {
      _showSnackBar('profile.data_export.ui.operation_cancelled'.tr(),
          isError: true);
      return;
    }

    setState(() => _isRequesting = true);
    final error = await ref.read(dataExportProvider.notifier).requestExport();
    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (error != null) {
      _showSnackBar(error, isError: true);
    } else {
      _showSnackBar('profile.data_export.ui.export_requested'.tr());
      _startPollingIfNeeded(ref.read(dataExportProvider).value ?? []);
    }
  }

  Future<void> _handleDownload(String exportId) async {
    HapticFeedback.lightImpact();
    setState(() => _downloadingIds.add(exportId));

    _showSnackBar('profile.data_export.ui.opening_download'.tr());

    final result =
        await ref.read(dataExportProvider.notifier).download(exportId);

    if (!mounted) return;
    setState(() => _downloadingIds.remove(exportId));

    if (result.error != null) {
      _showSnackBar(result.error!, isError: true);
      return;
    }

    // Download to a temp file and hand it to the native share sheet, so the
    // user can save it to Files or send it, instead of raw JSON in a browser.
    final exports = ref.read(dataExportProvider).value ?? const [];
    final export = exports.where((e) => e.exportId == exportId).firstOrNull;
    final fileName = dataExportFileName(export?.createdAt ?? DateTime.now());
    final origin = _shareOrigin();
    File? file;
    try {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/$fileName');
      // Plain Dio on purpose: the URL is a pre-signed R2 link, no auth header.
      await Dio().download(result.url!, file.path);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, name: fileName, mimeType: 'application/json')],
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (mounted) {
        _showSnackBar('profile.data_export.ui.download_file_error'.tr(),
            isError: true);
      }
    } finally {
      // The file holds personal data; keep no copy once the sheet closes.
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  /// Anchor for the share sheet popover on iPad.
  Rect? _shareOrigin() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// "Eliminar mi cuenta": the consequences sheet first, then the delete flow
  /// (password step, 409 re-warning...) without its own first confirmation.
  Future<void> _handleDeleteAccount() async {
    final result = await showDeleteConsequencesSheet(context);
    if (result == null || !mounted) return;

    switch (result.choice) {
      case DeleteConsequencesChoice.download:
        // Stay here: bring the copy panel into view.
        if (_scroll.hasClients) {
          if (SacMotion.reduceMotionOf(context)) {
            _scroll.jumpTo(0);
          } else {
            unawaited(_scroll.animateTo(
              0,
              duration: SacMotion.routeEnter,
              curve: SacMotion.easeOut,
            ));
          }
        }
      case DeleteConsequencesChoice.proceed:
        await widget.deleteAccountRunner(
          context,
          ref,
          skipFirstConfirm: true,
          initialDependentsAck: result.dependentsAck,
        );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final exportsAsync = ref.watch(dataExportProvider);
    final c = context.sac;
    final exports = exportsAsync.value;

    if (exports != null) _startPollingIfNeeded(exports);

    final now = DateTime.now();
    final hasActiveExport = exports?.any((e) => e.isInProgress) ?? false;
    // A ready copy inside the 24 h cooldown: the backend would answer 429.
    final nextAvailableAt = exports == null || _isRequesting || hasActiveExport
        ? null
        : nextDataExportAvailableAt(exports, now: now);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'settings.my_data_title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
        frosted: true,
      ),
      bottomNavigationBar: SacPinnedActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nextAvailableAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'settings.my_data.cooldown_note'.tr(namedArgs: {
                    'time': formatDataExportWait(
                      nextAvailableAt.difference(now),
                    ),
                  }),
                  key: const ValueKey('my-data-cooldown'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: c.textSecondary,
                  ),
                ),
              ),
            SacButton.primary(
              key: const ValueKey('my-data-request'),
              text: hasActiveExport
                  ? 'settings.my_data.in_progress'.tr()
                  : 'settings.my_data.request'.tr(),
              icon: HugeIcons.strokeRoundedDownload02,
              isLoading: _isRequesting,
              onPressed: exports == null ||
                      _isRequesting ||
                      hasActiveExport ||
                      nextAvailableAt != null
                  ? null
                  : _handleRequestExport,
            ),
          ],
        ),
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => RefreshIndicator(
            onRefresh: () => ref.read(dataExportProvider.notifier).refresh(),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.fromLTRB(16, 8, 16, 24),
              ),
              children: [
                if (exports == null)
                  _LoadingOrError(
                    error: exportsAsync.hasError ? exportsAsync.error : null,
                    onRetry: () =>
                        ref.read(dataExportProvider.notifier).refresh(),
                  )
                else ...[
                  MyDataStatePanel(
                    phase: myDataPhaseOf(exports),
                    exports: exports,
                    now: now,
                  ),
                  const SizedBox(height: 24),
                  _History(
                    exports: exports,
                    downloadingIds: _downloadingIds,
                    onDownload: _handleDownload,
                    now: now,
                  ),
                ],
                const SizedBox(height: 24),
                SacSettingsGroup(
                  title: 'settings.my_data.account_eyebrow'.tr().toUpperCase(),
                  children: [
                    SacSettingsTile(
                      key: const ValueKey('my-data-delete'),
                      icon: HugeIcons.strokeRoundedDelete02,
                      title: 'settings.my_data.delete_title'.tr(),
                      subtitle: 'settings.my_data.delete_subtitle'.tr(),
                      destructive: true,
                      onTap: _handleDeleteAccount,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SacSettingsGroup(
      children: [
        if (error != null)
          SacErrorState.inline(
            message: userErrorMessage(error!),
            onRetry: onRetry,
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: SacLoading()),
          ),
      ],
    );
  }
}

// ── History ───────────────────────────────────────────────────────────────────

class _History extends StatelessWidget {
  const _History({
    required this.exports,
    required this.downloadingIds,
    required this.onDownload,
    required this.now,
  });

  final List<DataExport> exports;
  final Set<String> downloadingIds;
  final Future<void> Function(String exportId) onDownload;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final sorted = [...exports]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SacSettingsGroup(
      title: 'settings.my_data.history_eyebrow'.tr().toUpperCase(),
      children: [
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Text(
              'settings.my_data.history_empty'.tr(),
              key: const ValueKey('my-data-history-empty'),
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textTertiary,
              ),
            ),
          )
        else
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) const SacSettingsDivider(),
            _ExportRow(
              export: sorted[i],
              now: now,
              isDownloading: downloadingIds.contains(sorted[i].exportId),
              onDownload: () => onDownload(sorted[i].exportId),
            ),
          ],
      ],
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.export,
    required this.now,
    required this.isDownloading,
    required this.onDownload,
  });

  final DataExport export;
  final DateTime now;
  final bool isDownloading;
  final VoidCallback onDownload;

  String _status() {
    switch (export.status) {
      case DataExportStatus.pending:
      case DataExportStatus.processing:
        return 'settings.my_data.status_preparing'.tr();
      case DataExportStatus.ready:
        final expires = export.expiresAt;
        final left = expires != null && expires.isAfter(now)
            ? 'settings.my_data.status_ready_left'.tr(namedArgs: {
                'time': formatDataExportWait(expires.difference(now)),
              })
            : 'settings.my_data.status_ready'.tr();
        final size = export.formattedSize;
        return size == null ? left : '$left · $size';
      case DataExportStatus.failed:
        return 'settings.my_data.status_failed'.tr();
      case DataExportStatus.expired:
        return 'settings.my_data.status_expired'.tr();
    }
  }

  HugeIconData _icon() {
    switch (export.status) {
      case DataExportStatus.pending:
      case DataExportStatus.processing:
        return HugeIcons.strokeRoundedLoading03;
      case DataExportStatus.ready:
        return HugeIcons.strokeRoundedFile02;
      case DataExportStatus.failed:
        return HugeIcons.strokeRoundedAlert02;
      case DataExportStatus.expired:
        return HugeIcons.strokeRoundedTime04;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = export.isReady;
    return SacSettingsTile(
      key: ValueKey('export-${export.exportId}'),
      icon: _icon(),
      title: 'settings.my_data.copy_of'.tr(namedArgs: {
        'date': SacDateFormatter.dayMonth(export.createdAt),
      }),
      subtitle: _status(),
      onTap: ready && !isDownloading ? onDownload : null,
      trailing: !ready
          ? const SizedBox.shrink()
          : SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: SacLoadingSmall(),
                      )
                    : Semantics(
                        button: true,
                        label: 'settings.my_data.download'.tr(),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedDownload02,
                          size: 20,
                          color: SacAccent.of(context).color,
                        ),
                      ),
              ),
            ),
    );
  }
}
