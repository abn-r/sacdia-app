import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/resource.dart';
import '../providers/resources_providers.dart';
import 'resource_card.dart';

/// Bottom sheet con el detalle completo de un recurso.
///
/// Comportamiento según tipo:
/// - document / audio / image: botón "Descargar" que obtiene signed URL
/// - video_link: botón "Ver video" que abre [externalUrl]
/// - text: muestra el contenido inline
class ResourceDetailSheet extends ConsumerStatefulWidget {
  final Resource resource;

  const ResourceDetailSheet({super.key, required this.resource});

  /// Abre el sheet como modal bottom sheet
  static Future<void> show(BuildContext context, Resource resource) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResourceDetailSheet(resource: resource),
    );
  }

  @override
  ConsumerState<ResourceDetailSheet> createState() =>
      _ResourceDetailSheetState();
}

class _ResourceDetailSheetState extends ConsumerState<ResourceDetailSheet> {
  bool _isOpeningUrl = false;

  Resource get _resource => widget.resource;

  Future<void> _openDownload() async {
    setState(() => _isOpeningUrl = true);

    final notifier = ref.read(signedUrlNotifierProvider.notifier);
    final url = await notifier.fetchSignedUrl(_resource.resourceId);

    if (url != null && mounted) {
      await _launchUrl(url);
    } else if (mounted) {
      _showError('No se pudo obtener la URL de descarga');
    }

    if (mounted) setState(() => _isOpeningUrl = false);
  }

  Future<void> _openExternalUrl() async {
    final rawUrl = _resource.externalUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      _showError('URL de video no disponible');
      return;
    }
    setState(() => _isOpeningUrl = true);
    await _launchUrl(rawUrl);
    if (mounted) setState(() => _isOpeningUrl = false);
  }

  Future<void> _launchUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) {
      _showError('URL no válida');
      return;
    }
    final canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showError('No se pudo abrir la URL');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final signedUrlState = ref.watch(signedUrlNotifierProvider);
    final color = resourceTypeColor(_resource.resourceType);
    final icon = resourceTypeIcon(_resource.resourceType);

    return DraggableScrollableSheet(
      initialChildSize: _resource.resourceType == 'text' ? 0.75 : 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // ── Drag handle ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Icon + type badge ────────────────────────
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: icon,
                            size: 28,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Title ────────────────────────────────────
                      Text(
                        _resource.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          height: 1.3,
                        ),
                      ),
                      if (_resource.categoryName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _resource.categoryName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      // ── Meta row ─────────────────────────────────
                      if (_resource.fileSize != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedInformationCircle,
                              size: 14,
                              color: c.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatFileSize(_resource.fileSize),
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // ── Description ──────────────────────────────
                      if (_resource.description != null &&
                          _resource.description!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _resource.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],

                      // ── Text content ─────────────────────────────
                      if (_resource.resourceType == 'text' &&
                          _resource.content != null &&
                          _resource.content!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(color: c.border),
                          ),
                          child: Text(
                            _resource.content!,
                            style: TextStyle(
                              fontSize: 14,
                              color: c.text,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Error from signed URL ────────────────────
                      if (signedUrlState.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            signedUrlState.error.toString(),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      // ── Action button ────────────────────────────
                      _buildActionButton(context, color),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, Color color) {
    final type = _resource.resourceType;
    final bool isText = type == 'text';

    // Sin acción de apertura para texto (ya se muestra inline)
    if (isText) return const SizedBox.shrink();

    final bool isVideo = type == 'video_link';
    final label = isVideo ? 'Ver video' : 'Descargar';
    final icon = isVideo
        ? HugeIcons.strokeRoundedPlayCircle
        : HugeIcons.strokeRoundedDownload01;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isOpeningUrl
            ? null
            : () {
                if (isVideo) {
                  _openExternalUrl();
                } else {
                  _openDownload();
                }
              },
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
        ),
        icon: _isOpeningUrl
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : HugeIcon(
                icon: icon,
                size: 18,
                color: Colors.white,
              ),
        label: Text(
          _isOpeningUrl ? 'Abriendo...' : label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
