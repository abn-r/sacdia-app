import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/resource.dart';
import '../providers/resources_providers.dart';
import '../utils/resource_format.dart';
import '../utils/resource_preview.dart';
import 'resource_audio_player.dart';
import 'resource_card.dart';
import 'resource_info_group.dart';

/// Bottom sheet con el detalle completo de un recurso.
///
/// Portada y título, una línea "TIPO · tamaño · fecha", un grupo de
/// etiqueta-valor (categoría, para qué club, quién lo publicó) y las acciones
/// fijas abajo. Según el tipo:
/// - audio: reproductor embebido; Descargar y Compartir como secundarias
/// - image: "Ver imagen" primaria
/// - document: "Abrir PDF" primaria cuando aplica; si no, "Descargar"
/// - video_link: "Abrir en YouTube" con aviso de que sale de la app
/// - text: muestra el contenido inline, sin acciones
class ResourceDetailSheet extends ConsumerStatefulWidget {
  final Resource resource;

  const ResourceDetailSheet({super.key, required this.resource});

  /// Abre el sheet como modal bottom sheet
  static Future<void> show(BuildContext context, Resource resource) {
    return showSacSheet(
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
  _ResourceAction? _loadingAction;

  Resource get _resource => widget.resource;

  Future<void> _openDownload() async {
    setState(() => _loadingAction = _ResourceAction.download);

    final url = await _resolveSignedUrl();

    if (url != null && mounted) {
      await _launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showError('resources.error.download_url'.tr());
    }

    if (mounted) setState(() => _loadingAction = null);
  }

  Future<void> _viewPdf() async {
    setState(() => _loadingAction = _ResourceAction.viewPdf);

    final url = await _resolveSignedUrl();

    if (url != null && mounted) {
      SacPdfViewer.show(context, pdfSource: url, title: _resource.title);
    } else if (mounted) {
      _showError('resources.error.media_url'.tr());
    }

    if (mounted) setState(() => _loadingAction = null);
  }

  Future<void> _viewImage() async {
    setState(() => _loadingAction = _ResourceAction.viewImage);

    final url = await _resolveSignedUrl();

    if (url != null && mounted) {
      SacImageViewer.show(context, imageUrl: url, title: _resource.title);
    } else if (mounted) {
      _showError('resources.error.media_url'.tr());
    }

    if (mounted) setState(() => _loadingAction = null);
  }

  /// Shares the title and the link: the video URL, or the signed file URL
  /// (which expires, like the one "Descargar" opens).
  Future<void> _share() async {
    setState(() => _loadingAction = _ResourceAction.share);

    final isVideo = _resource.resourceType == 'video_link';
    final url = isVideo ? _resource.externalUrl : await _resolveSignedUrl();

    if (url != null && url.isNotEmpty && mounted) {
      try {
        await ref.read(resourceSharerProvider)(
          text: '${_resource.title}\n$url',
          subject: _resource.title,
        );
      } catch (_) {
        _showError('resources.error.share_failed'.tr());
      }
    } else if (mounted) {
      _showError('resources.error.media_url'.tr());
    }

    if (mounted) setState(() => _loadingAction = null);
  }

  Future<String?> _resolveSignedUrl() async {
    final cachedUrl = _resource.signedUrl;
    if (cachedUrl != null && cachedUrl.isNotEmpty) return cachedUrl;

    final notifier = ref.read(signedUrlNotifierProvider.notifier);
    return notifier.fetchSignedUrl(_resource.resourceId);
  }

  Future<void> _openExternalUrl() async {
    final rawUrl = _resource.externalUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      _showError('resources.error.video_url_missing'.tr());
      return;
    }
    setState(() => _loadingAction = _ResourceAction.openVideo);
    await _launchUrl(rawUrl, mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _loadingAction = null);
  }

  Future<void> _launchUrl(
    String rawUrl, {
    required LaunchMode mode,
  }) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) {
      _showError('resources.error.invalid_url'.tr());
      return;
    }
    final canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      final launched = await launchUrl(uri, mode: mode);
      if (!launched && mounted) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (mounted) {
      _showError('resources.error.open_url_failed'.tr());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    SacSnackBar.show(context, message);
  }

  String _metaLine(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final size = formatResourceFileSize(_resource.fileSize);
    return [
      resourceLabelFor(_resource),
      if (size.isNotEmpty) size,
      DateFormat.yMMMd(locale).format(_resource.createdAt.toLocal()),
    ].join(' · ');
  }

  List<ResourceInfoRow> _infoRows() {
    final category = _resource.categoryName?.trim();
    final club = _resource.clubTypeName?.trim();
    final publisher = switch (_resource.scopeLevel) {
      'system' => 'resources.scope.system'.tr(),
      'union' => 'resources.scope.union'.tr(),
      'local_field' => 'resources.scope.local_field'.tr(),
      _ => null,
    };
    return [
      if (category != null && category.isNotEmpty)
        ResourceInfoRow(
          label: 'resources.detail.category'.tr(),
          value: category,
        ),
      if (club != null && club.isNotEmpty)
        ResourceInfoRow(
          label: 'resources.detail.for'.tr(),
          value: club,
          logoAsset: clubLogoAssetFromName(club),
        ),
      if (publisher != null)
        ResourceInfoRow(
          label: 'resources.detail.published_by'.tr(),
          value: publisher,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final signedUrlState = ref.watch(signedUrlNotifierProvider);
    final cachedSigned = _resource.signedUrl;
    final shouldFetch = resourceWantsSignedPreview(_resource);
    final fetched = shouldFetch
        ? ref.watch(resourcePreviewSignedUrlProvider(_resource.resourceId))
        : null;
    final imageUrl = (cachedSigned != null && cachedSigned.isNotEmpty)
        ? cachedSigned
        : fetched?.value;
    final initialChildSize = switch (_resource.resourceType) {
      'text' => 0.82,
      'image' => 0.8,
      'audio' => 0.88,
      'video_link' => 0.76,
      _ => 0.72,
    };
    final infoRows = _infoRows();
    final description = _resource.description;

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLG),
            ),
          ),
          child: Column(
            children: [
              const SacSheetGrabber(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: ResourcePreviewPane(
                            resource: _resource,
                            imageUrl: imageUrl,
                            videoThumbUrl:
                                videoPreviewUrl(_resource.externalUrl),
                            isImageLoading: fetched?.isLoading ?? false,
                            showTypeBadge: false,
                            textMaxLines: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _resource.title,
                        style: TextStyle(
                          fontSize: SacFontSize.headlineMedium,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _metaLine(context),
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          fontWeight: FontWeight.w500,
                          color: c.textTertiary,
                        ),
                      ),
                      if (_resource.resourceType == 'audio') ...[
                        const SizedBox(height: 16),
                        ResourceAudioPlayer(
                          resolveSignedUrl: _resolveSignedUrl,
                          onError: _showError,
                        ),
                      ],
                      if (infoRows.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ResourceInfoGroup(rows: infoRows),
                      ],
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            color: c.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                      if (_resource.resourceType == 'text' &&
                          _resource.content != null &&
                          _resource.content!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surfaceVariant,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(color: c.border),
                          ),
                          child: Text(
                            _resource.content!,
                            style: TextStyle(
                              fontSize: SacFontSize.titleMedium,
                              color: c.text,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                      if (signedUrlState.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            userErrorMessage(signedUrlState.error),
                            style: TextStyle(
                              color: c.error,
                              fontSize: SacFontSize.bodyMedium,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _buildActionBar(context),
            ],
          ),
        );
      },
    );
  }

  /// Fixed footer: one primary action, then Descargar / Compartir side by side.
  Widget _buildActionBar(BuildContext context) {
    final type = _resource.resourceType;
    if (type == 'text') return const SizedBox.shrink();

    final c = context.sac;
    final isPdf = resourceIsPdf(_resource);
    final isVideo = type == 'video_link';
    final externalVideo = isVideo && isExternalWebUrl(_resource.externalUrl);
    final busy = _loadingAction != null;

    // Documents the app cannot open in-app have no viewer: Descargar is then
    // the one primary action.
    final downloadIsPrimary = type == 'document' && !isPdf;

    final Widget? primary;
    if (isVideo) {
      primary = _ResourceActionButton(
        text: externalVideo
            ? (isYoutubeUrl(_resource.externalUrl)
                ? 'resources.action.open_youtube'.tr()
                : 'resources.action.open_link'.tr())
            : 'resources.action.watch_video'.tr(),
        icon: externalVideo
            ? HugeIcons.strokeRoundedSquareArrowUpRight
            : HugeIcons.strokeRoundedPlayCircle,
        isLoading: _loadingAction == _ResourceAction.openVideo,
        disabled: busy,
        onPressed: _openExternalUrl,
      );
    } else if (type == 'image') {
      primary = _ResourceActionButton(
        text: 'resources.action.view_image'.tr(),
        icon: HugeIcons.strokeRoundedImage01,
        isLoading: _loadingAction == _ResourceAction.viewImage,
        disabled: busy,
        onPressed: _viewImage,
      );
    } else if (isPdf) {
      primary = _ResourceActionButton(
        text: 'resources.action.open_pdf'.tr(),
        icon: HugeIcons.strokeRoundedFile01,
        isLoading: _loadingAction == _ResourceAction.viewPdf,
        disabled: busy,
        onPressed: _viewPdf,
      );
    } else if (downloadIsPrimary) {
      primary = _ResourceActionButton(
        text: 'resources.action.download'.tr(),
        icon: HugeIcons.strokeRoundedDownload01,
        isLoading: _loadingAction == _ResourceAction.download,
        disabled: busy,
        onPressed: _openDownload,
      );
    } else {
      primary = null; // audio: the large play button is the primary action
    }

    final secondary = <Widget>[
      if (!isVideo && !downloadIsPrimary)
        _ResourceActionButton(
          text: 'resources.action.download'.tr(),
          icon: HugeIcons.strokeRoundedDownload01,
          isLoading: _loadingAction == _ResourceAction.download,
          disabled: busy,
          onPressed: _openDownload,
          secondary: true,
        ),
      if (!isVideo)
        _ResourceActionButton(
          text: 'resources.action.share'.tr(),
          icon: HugeIcons.strokeRoundedShare01,
          isLoading: _loadingAction == _ResourceAction.share,
          disabled: busy,
          onPressed: _share,
          secondary: true,
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (primary != null) primary,
              if (externalVideo) ...[
                const SizedBox(height: 8),
                Text(
                  'resources.video.opens_outside'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: c.textTertiary,
                  ),
                ),
              ],
              if (primary != null && secondary.isNotEmpty)
                const SizedBox(height: 10),
              if (secondary.isNotEmpty)
                Row(
                  children: [
                    for (var i = 0; i < secondary.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: secondary[i]),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ResourceAction { viewImage, viewPdf, download, openVideo, share }

class _ResourceActionButton extends StatelessWidget {
  final String text;
  final HugeIconData icon;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onPressed;
  final bool secondary;

  const _ResourceActionButton({
    required this.text,
    required this.icon,
    required this.isLoading,
    required this.disabled,
    required this.onPressed,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final loadingLabel = 'resources.action.opening'.tr();
    if (secondary) {
      return SacButton.outline(
        text: text,
        icon: icon,
        isLoading: isLoading,
        isEnabled: !disabled,
        loadingSemanticLabel: loadingLabel,
        onPressed: disabled ? null : onPressed,
      );
    }

    return SacButton.primary(
      text: text,
      icon: icon,
      isLoading: isLoading,
      isEnabled: !disabled,
      loadingSemanticLabel: loadingLabel,
      onPressed: disabled ? null : onPressed,
    );
  }
}
