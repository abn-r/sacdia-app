import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/media/sac_audio_player_controller.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/resource.dart';
import '../providers/resources_providers.dart';
import 'resource_card.dart';

/// Bottom sheet con el detalle completo de un recurso.
///
/// Comportamiento según tipo:
/// - audio: reproductor embebido + "Descargar" con signed URL
/// - image: botón "Ver imagen" + "Descargar" con signed URL
/// - document: botón "Ver PDF" cuando aplica + "Descargar" con signed URL
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final signedUrlState = ref.watch(signedUrlNotifierProvider);
    final color = resourceTypeColor(context, _resource.resourceType);
    final icon = resourceTypeIcon(_resource.resourceType);
    final initialChildSize = switch (_resource.resourceType) {
      'text' => 0.75,
      'image' => 0.68,
      'audio' => 0.72,
      _ => 0.55,
    };

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
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

                      if (_resource.resourceType == 'audio') ...[
                        const SizedBox(height: 16),
                        _ResourceAudioPlayer(
                          resource: _resource,
                          accentColor: color,
                          resolveSignedUrl: _resolveSignedUrl,
                          onError: _showError,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Error from signed URL ────────────────────
                      if (signedUrlState.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            signedUrlState.error.toString(),
                            style: TextStyle(
                              color: c.error,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      // ── Action buttons ───────────────────────────
                      _buildActionButtons(context, color),
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

  Widget _buildActionButtons(BuildContext context, Color color) {
    final type = _resource.resourceType;
    final bool isText = type == 'text';

    // Sin acción de apertura para texto (ya se muestra inline)
    if (isText) return const SizedBox.shrink();

    if (type == 'video_link') {
      return _ResourceActionButton(
        text: 'resources.action.watch_video'.tr(),
        loadingText: 'resources.action.opening'.tr(),
        icon: HugeIcons.strokeRoundedPlayCircle,
        color: color,
        isLoading: _loadingAction == _ResourceAction.openVideo,
        disabled: _loadingAction != null,
        onPressed: _openExternalUrl,
      );
    }

    final actions = <Widget>[
      if (type == 'image')
        _ResourceActionButton(
          text: 'resources.action.view_image'.tr(),
          loadingText: 'resources.action.opening'.tr(),
          icon: HugeIcons.strokeRoundedImage01,
          color: color,
          isLoading: _loadingAction == _ResourceAction.viewImage,
          disabled: _loadingAction != null,
          onPressed: _viewImage,
        ),
      if (_isPdfDocument)
        _ResourceActionButton(
          text: 'resources.action.view_pdf'.tr(),
          loadingText: 'resources.action.opening'.tr(),
          icon: HugeIcons.strokeRoundedFile01,
          color: color,
          isLoading: _loadingAction == _ResourceAction.viewPdf,
          disabled: _loadingAction != null,
          onPressed: _viewPdf,
        ),
      _ResourceActionButton(
        text: 'resources.action.download'.tr(),
        loadingText: 'resources.action.opening'.tr(),
        icon: HugeIcons.strokeRoundedDownload01,
        color: color,
        isLoading: _loadingAction == _ResourceAction.download,
        disabled: _loadingAction != null,
        onPressed: _openDownload,
        secondary: type == 'audio' || type == 'image' || _isPdfDocument,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          actions[i],
        ],
      ],
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

  bool get _isPdfDocument {
    if (_resource.resourceType != 'document') return false;
    final mime = _resource.fileMimeType?.toLowerCase() ?? '';
    final name = _resource.fileName?.toLowerCase() ?? '';
    return mime.contains('pdf') || name.endsWith('.pdf');
  }
}

enum _ResourceAction { viewImage, viewPdf, download, openVideo }

class _ResourceActionButton extends StatelessWidget {
  final String text;
  final String loadingText;
  final List<List<dynamic>> icon;
  final Color color;
  final bool isLoading;
  final bool disabled;
  final VoidCallback onPressed;
  final bool secondary;

  const _ResourceActionButton({
    required this.text,
    required this.loadingText,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.disabled,
    required this.onPressed,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacButton(
      text: isLoading ? loadingText : text,
      icon: icon,
      isLoading: isLoading,
      fullWidth: true,
      backgroundColor: secondary ? c.surface : color,
      textColor: secondary ? color : Colors.white,
      borderRadius: AppTheme.radiusMD,
      onPressed: disabled ? null : onPressed,
      variant: secondary ? SacButtonVariant.outline : SacButtonVariant.primary,
    );
  }
}

enum _AudioStatus { idle, loading, playing, paused, error }

class _ResourceAudioPlayer extends StatefulWidget {
  final Resource resource;
  final Color accentColor;
  final Future<String?> Function() resolveSignedUrl;
  final ValueChanged<String> onError;

  const _ResourceAudioPlayer({
    required this.resource,
    required this.accentColor,
    required this.resolveSignedUrl,
    required this.onError,
  });

  @override
  State<_ResourceAudioPlayer> createState() => _ResourceAudioPlayerState();
}

class _ResourceAudioPlayerState extends State<_ResourceAudioPlayer> {
  final SacAudioPlayerController _player = SacAudioPlayerController();
  _AudioStatus _status = _AudioStatus.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _positionTimer;

  bool get _isBusy => _status == _AudioStatus.loading;
  bool get _isPlaying => _status == _AudioStatus.playing;
  bool get _hasStarted =>
      _status == _AudioStatus.playing || _status == _AudioStatus.paused;

  @override
  void dispose() {
    _positionTimer?.cancel();
    _player.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isBusy) return;

    if (_isPlaying) {
      await _pause();
      return;
    }

    if (_hasStarted) {
      await _resume();
      return;
    }

    await _start();
  }

  Future<void> _start() async {
    setState(() => _status = _AudioStatus.loading);

    try {
      final url = await widget.resolveSignedUrl();
      if (url == null || url.isEmpty) {
        _fail('resources.error.media_url'.tr());
        return;
      }

      await _player.playUrl(url);
      if (!mounted) return;
      setState(() => _status = _AudioStatus.playing);
      _startPositionTimer();
      await _refreshPosition();
    } catch (_) {
      _fail('resources.error.audio_playback'.tr());
    }
  }

  Future<void> _pause() async {
    try {
      await _player.pause();
      if (mounted) setState(() => _status = _AudioStatus.paused);
      _positionTimer?.cancel();
      await _refreshPosition();
    } catch (_) {
      _fail('resources.error.audio_playback'.tr());
    }
  }

  Future<void> _resume() async {
    try {
      await _player.resume();
      if (mounted) setState(() => _status = _AudioStatus.playing);
      _startPositionTimer();
      await _refreshPosition();
    } catch (_) {
      _fail('resources.error.audio_playback'.tr());
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _status = _AudioStatus.error);
    _positionTimer?.cancel();
    widget.onError(message);
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshPosition(),
    );
  }

  Future<void> _refreshPosition() async {
    try {
      final playback = await _player.position();
      if (!mounted) return;
      setState(() {
        _position = playback.position;
        _duration = playback.duration;
        if (_status == _AudioStatus.playing && !playback.isPlaying) {
          _status = _AudioStatus.paused;
          _positionTimer?.cancel();
        }
      });
    } catch (_) {
      // Position polling is best-effort; do not interrupt playback UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final progress = _duration.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'resources.audio.player_title'.tr(),
            style: TextStyle(
              color: c.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: c.border,
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(fontSize: 12, color: c.textTertiary),
              ),
              const Spacer(),
              Text(
                _duration == Duration.zero
                    ? '--:--'
                    : _formatDuration(_duration),
                style: TextStyle(fontSize: 12, color: c.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SacButton(
            text: _buttonLabel,
            icon: _isPlaying
                ? HugeIcons.strokeRoundedPause
                : HugeIcons.strokeRoundedPlayCircle,
            isLoading: _isBusy,
            fullWidth: true,
            backgroundColor: widget.accentColor,
            borderRadius: AppTheme.radiusMD,
            onPressed: _isBusy ? null : _toggle,
          ),
        ],
      ),
    );
  }

  String get _buttonLabel {
    if (_isBusy) return 'resources.audio.loading'.tr();
    if (_isPlaying) return 'resources.audio.pause'.tr();
    if (_hasStarted) return 'resources.audio.resume'.tr();
    return 'resources.action.play_audio'.tr();
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
