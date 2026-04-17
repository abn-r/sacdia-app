import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/data_export.dart';
import '../providers/data_export_providers.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formatea un DateTime con fecha y hora en español rioplatense.
/// Ej: "25 de marzo de 2026, 14:30"
String _formatDateTime(DateTime dt) {
  // SacDateFormatter.dateTimeShort retorna "d MMM yyyy, HH:mm" — p.ej. "17 abr 2026, 14:32"
  return SacDateFormatter.dateTimeShort(dt);
}

/// Formatea fecha de expiración corta.
/// Ej: "17/04/2026, 14:32"
String _formatExpiry(DateTime dt) {
  return SacDateFormatter.dateTime(dt);
}

/// Retorna el ícono HugeIcons apropiado según el status de la exportación.
HugeIconData _iconForStatus(DataExportStatus status) {
  switch (status) {
    case DataExportStatus.pending:
    case DataExportStatus.processing:
      return HugeIcons.strokeRoundedLoading03;
    case DataExportStatus.ready:
      return HugeIcons.strokeRoundedCheckmarkCircle02;
    case DataExportStatus.failed:
      return HugeIcons.strokeRoundedAlert02;
    case DataExportStatus.expired:
      return HugeIcons.strokeRoundedTime04;
  }
}

/// Color del ícono según status.
Color _colorForStatus(DataExportStatus status, SacColors c) {
  switch (status) {
    case DataExportStatus.pending:
    case DataExportStatus.processing:
      return AppColors.primary;
    case DataExportStatus.ready:
      return AppColors.success;
    case DataExportStatus.failed:
      return AppColors.error;
    case DataExportStatus.expired:
      return c.textTertiary;
  }
}

// ── View ──────────────────────────────────────────────────────────────────────

class DataExportView extends ConsumerStatefulWidget {
  const DataExportView({super.key});

  @override
  ConsumerState<DataExportView> createState() => _DataExportViewState();
}

class _DataExportViewState extends ConsumerState<DataExportView> {
  bool _isRequesting = false;
  final Set<String> _downloadingIds = {};
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  /// Inicia polling cada 10s si hay exports en progreso.
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
    final notifier = ref.read(dataExportProvider.notifier);
    await notifier.refresh();
    // Después del refresh, verificar si ya no hay exports en progreso.
    final current = ref.read(dataExportProvider).valueOrNull ?? [];
    if (!current.any((e) => e.isInProgress)) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _handleRequestExport() async {
    HapticFeedback.mediumImpact();
    setState(() => _isRequesting = true);

    final error = await ref
        .read(dataExportProvider.notifier)
        .requestExport();

    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (error != null) {
      _showSnackBar(error, isError: true);
    } else {
      _showSnackBar('Exportación solicitada. Te avisaremos cuando esté lista.');
      // Iniciar polling para la nueva export en progreso.
      final current = ref.read(dataExportProvider).valueOrNull ?? [];
      _startPollingIfNeeded(current);
    }
  }

  Future<void> _handleDownload(String exportId) async {
    HapticFeedback.lightImpact();
    setState(() => _downloadingIds.add(exportId));

    _showSnackBar('Abriendo descarga...');

    final result = await ref
        .read(dataExportProvider.notifier)
        .download(exportId);

    if (!mounted) return;
    setState(() => _downloadingIds.remove(exportId));

    if (result.error != null) {
      _showSnackBar(result.error!, isError: true);
      return;
    }

    final url = result.url!;
    final uri = Uri.parse(url);

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showSnackBar('No se pudo abrir el enlace de descarga.', isError: true);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final exportsAsync = ref.watch(dataExportProvider);
    final c = context.sac;

    // Arrancar/detener polling según el estado actual.
    exportsAsync.whenData((exports) {
      _startPollingIfNeeded(exports);
    });

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        title: const Text('Descargar mis datos'),
        backgroundColor: c.surfaceVariant,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: exportsAsync.when(
        loading: () => _buildBody(
          context: context,
          exports: null,
          isLoading: true,
        ),
        error: (error, _) => _ErrorState(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.read(dataExportProvider.notifier).refresh(),
        ),
        data: (exports) => _buildBody(
          context: context,
          exports: exports,
          isLoading: false,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required List<DataExport>? exports,
    required bool isLoading,
  }) {
    final c = context.sac;

    // ¿Hay alguna export activa (pending/processing) que bloquee el botón?
    final hasActiveExport =
        exports?.any((e) => e.isInProgress) ?? false;
    final isButtonDisabled = _isRequesting || hasActiveExport;

    return RefreshIndicator(
      onRefresh: () => ref.read(dataExportProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Header informativo ─────────────────────────────────────
          _InfoCard(c: c),
          const SizedBox(height: 20),

          // ── Botón de solicitud ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isButtonDisabled ? null : _handleRequestExport,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isRequesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedDownload02,
                      size: 18,
                      color: Colors.white,
                    ),
              label: Text(
                _isRequesting
                    ? 'Solicitando...'
                    : hasActiveExport
                        ? 'Exportación en curso...'
                        : 'Solicitar exportación de datos',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Lista de solicitudes ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'HISTORIAL DE SOLICITUDES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
          ),

          if (isLoading)
            _LoadingSkeleton(c: c)
          else if (exports == null || exports.isEmpty)
            _EmptyState(c: c)
          else
            _ExportList(
              exports: exports,
              downloadingIds: _downloadingIds,
              onDownload: _handleDownload,
              c: c,
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final SacColors c;

  const _InfoCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Sobre tu exportación de datos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(
            context,
            icon: HugeIcons.strokeRoundedFileDownload,
            text: 'Incluye tu perfil, actividades, logros y más en formato JSON.',
          ),
          const SizedBox(height: 6),
          _infoRow(
            context,
            icon: HugeIcons.strokeRoundedTime04,
            text: 'El archivo estará disponible para descargar durante 48 horas.',
          ),
          const SizedBox(height: 6),
          _infoRow(
            context,
            icon: HugeIcons.strokeRoundedClock01,
            text: 'Podés solicitar una exportación cada 24 horas.',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, {
    required HugeIconData icon,
    required String text,
  }) {
    final c = context.sac;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: HugeIcon(
            icon: icon,
            size: 14,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  final SacColors c;

  const _LoadingSkeleton({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        children: List.generate(3, (i) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _SkeletonBox(width: 36, height: 36, radius: 8, c: c),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(
                            width: double.infinity,
                            height: 13,
                            radius: 4,
                            c: c,
                          ),
                          const SizedBox(height: 6),
                          _SkeletonBox(width: 120, height: 11, radius: 4, c: c),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 2)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 62,
                  color: c.borderLight,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final SacColors c;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.borderLight,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final SacColors c;

  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFileDownload,
            size: 40,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no solicitaste exportaciones',
            style: TextStyle(
              fontSize: 14,
              color: c.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
              style: TextStyle(fontSize: 15, color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 16,
                color: Colors.white,
              ),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Export list ───────────────────────────────────────────────────────────────

class _ExportList extends StatelessWidget {
  final List<DataExport> exports;
  final Set<String> downloadingIds;
  final Future<void> Function(String exportId) onDownload;
  final SacColors c;

  const _ExportList({
    required this.exports,
    required this.downloadingIds,
    required this.onDownload,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        children: List.generate(exports.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(
              height: 1,
              thickness: 1,
              indent: 62,
              color: c.borderLight,
            );
          }
          final export = exports[i ~/ 2];
          return _ExportCard(
            export: export,
            isDownloading: downloadingIds.contains(export.exportId),
            onDownload: () => onDownload(export.exportId),
            c: c,
          );
        }),
      ),
    );
  }
}

// ── Export card ───────────────────────────────────────────────────────────────

class _ExportCard extends StatelessWidget {
  final DataExport export;
  final bool isDownloading;
  final VoidCallback onDownload;
  final SacColors c;

  const _ExportCard({
    required this.export,
    required this.isDownloading,
    required this.onDownload,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _colorForStatus(export.status, c);
    final iconBg = statusColor.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícono de status
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: HugeIcon(
                icon: _iconForStatus(export.status),
                size: 18,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Detalles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fecha de solicitud como título
                Text(
                  _formatDateTime(export.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Subtítulo con status localizado
                Text(
                  export.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Info adicional según status
                if (export.isReady) ...[
                  if (export.formattedSize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      export.formattedSize!,
                      style: TextStyle(fontSize: 11, color: c.textTertiary),
                    ),
                  ],
                  if (export.expiresAt != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      'Expira el ${_formatExpiry(export.expiresAt!)}',
                      style: TextStyle(fontSize: 11, color: c.textTertiary),
                    ),
                  ],
                ],

                if (export.status == DataExportStatus.failed &&
                    export.failureReason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    export.failureReason!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (export.status == DataExportStatus.failed) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ocurrió un error al generar tu exportación.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Trailing: botón descargar si ready
          if (export.isReady) ...[
            const SizedBox(width: 8),
            _DownloadButton(
              isDownloading: isDownloading,
              onDownload: onDownload,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Download button ───────────────────────────────────────────────────────────

class _DownloadButton extends StatelessWidget {
  final bool isDownloading;
  final VoidCallback onDownload;

  const _DownloadButton({
    required this.isDownloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }

    return GestureDetector(
      onTap: onDownload,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedDownload02,
            size: 18,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
