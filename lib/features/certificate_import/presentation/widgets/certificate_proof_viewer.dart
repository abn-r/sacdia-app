import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/certificate_import_file.dart';
import '../providers/certificate_import_providers.dart';

/// Optional `extra` of the proof route. When it is lost (deep link, process
/// restore) the viewer recovers the file data from the batch.
class CertificateProofArgs {
  const CertificateProofArgs({
    this.fileName,
    this.mimeType,
    this.pageCount,
    this.localPath,
  });

  final String? fileName;
  final String? mimeType;
  final int? pageCount;
  final String? localPath;
}

/// Full-screen viewer of the sealed proof: an image with zoom or a paged PDF.
///
/// Uses [localPath] without network when the file still exists; otherwise asks
/// for a fresh signed URL on every open and every retry (never cached).
class CertificateProofViewer extends ConsumerStatefulWidget {
  const CertificateProofViewer({
    super.key,
    required this.batchId,
    required this.fileId,
    this.fileName,
    this.mimeType,
    this.pageCount,
    this.initialPage = 1,
    this.localPath,
  });

  final String batchId;
  final String fileId;
  final String? fileName;
  final String? mimeType;
  final int? pageCount;

  /// 1-based. Ignored for images.
  final int initialPage;
  final String? localPath;

  static String heroTagFor(String fileId) => 'certificate-proof-$fileId';

  /// Builds the viewer from the proof route. The page comes from `?page=` and
  /// the file data from `extra`; both are optional and recovered when absent.
  factory CertificateProofViewer.fromRouteState(GoRouterState state) {
    final extra = state.extra;
    final args = extra is CertificateProofArgs ? extra : null;
    return CertificateProofViewer(
      batchId: state.pathParameters['batchId']!,
      fileId: state.pathParameters['fileId']!,
      initialPage: int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 1,
      fileName: args?.fileName,
      mimeType: args?.mimeType,
      pageCount: args?.pageCount,
      localPath: args?.localPath,
    );
  }

  /// Opens the viewer by route; it does not depend on any item.
  static void open(
    BuildContext context, {
    required String batchId,
    required CertificateImportFile file,
    int initialPage = 1,
    String? localPath,
  }) {
    context.push(
      RouteNames.certificateImportProofPath(batchId, file.id,
          page: initialPage),
      extra: CertificateProofArgs(
        fileName: file.name,
        mimeType: file.type,
        pageCount: file.pageCount,
        localPath: localPath,
      ),
    );
  }

  @override
  ConsumerState<CertificateProofViewer> createState() =>
      _CertificateProofViewerState();
}

class _CertificateProofViewerState
    extends ConsumerState<CertificateProofViewer> {
  String? _source;
  bool _isPdf = false;
  int? _pageCount;
  String? _errorKey;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_source != null || _errorKey != null) {
      setState(() {
        _source = null;
        _errorKey = null;
        _attempt++;
      });
    }
    var name = widget.fileName;
    var mime = widget.mimeType;
    var count = widget.pageCount;
    final local = widget.localPath;
    final hasLocal = local != null && File(local).existsSync();

    if (name == null && mime == null && !hasLocal) {
      try {
        final batch = await ref
            .read(certificateImportBatchProvider(widget.batchId).future);
        final file =
            batch.files.where((f) => f.id == widget.fileId).firstOrNull;
        if (!mounted) return;
        if (file == null) return _fail('not_found');
        (name, mime, count) = (file.name, file.type, file.pageCount);
      } catch (_) {
        return _fail('error');
      }
    }

    String? source = hasLocal ? local : null;
    if (source == null) {
      final result = await ref
          .read(signedCertificateImportDownloadProvider)
          .call(batchId: widget.batchId, fileId: widget.fileId);
      source = result.fold<String?>(
        (failure) {
          // Never show the raw message: it can carry backend codes.
          _errorKey = failure.message.contains('FILE_NOT_CONFIRMED')
              ? 'processing'
              : 'error';
          return null;
        },
        (url) => url,
      );
    }
    if (!mounted) return;
    if (source == null) return _fail(_errorKey ?? 'error');
    setState(() {
      _source = source;
      _errorKey = null;
      _pageCount = count;
      _isPdf = [mime, name, local]
          .any((v) => v != null && v.toLowerCase().contains('pdf'));
    });
  }

  void _fail(String key) {
    if (mounted) setState(() => _errorKey = key);
  }

  Future<void> _openExternal() async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(_source ?? '');
    final opened = uri != null &&
        uri.scheme == 'https' &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      SacSnackBar.showMessenger(
        messenger,
        'certificate_import.viewer.error'.tr(),
        isError: true,
      );
    }
  }

  List<Widget> _actions() {
    final source = _source;
    if (source == null || !source.startsWith('https://')) return const [];
    return [
      PopupMenuButton<void>(
        tooltip: 'certificate_import.viewer.more'.tr(),
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedMoreVertical,
          color: Colors.white,
        ),
        onSelected: (_) => _openExternal(),
        itemBuilder: (_) => [
          PopupMenuItem<void>(
            child: Text('certificate_import.viewer.open_external'.tr()),
          ),
        ],
      ),
    ];
  }

  Widget _message(String key, {bool retry = true}) => _ProofMessage(
        text: 'certificate_import.viewer.$key'.tr(),
        onRetry: retry ? _load : null,
      );

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final title = 'certificate_import.viewer.title'.tr();
    if (source != null) {
      final key = ValueKey('$_attempt-$source');
      return _isPdf
          ? SacPdfViewer(
              key: key,
              pdfSource: source,
              title: title,
              horizontalPaged: true,
              initialPage: widget.initialPage,
              pageCount: _pageCount,
              allowShare: false,
              dark: true,
              actions: _actions(),
              errorBuilder: (_) => _message('error'),
            )
          : SacImageViewer.gallery(
              key: key,
              imageUrls: [source],
              title: title,
              allowShare: false,
              cacheNetwork: false,
              heroTag: CertificateProofViewer.heroTagFor(widget.fileId),
              semanticLabel: 'certificate_import.viewer.image_label'.tr(),
              actions: _actions(),
              errorBuilder: (_) => _message('error'),
            );
    }
    final failed = _errorKey;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: SacTopBar(
          title: title,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: Colors.white,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
        body: failed != null
            ? _message(failed, retry: failed != 'not_found')
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SacLoading(color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      'certificate_import.viewer.opening'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProofMessage extends StatelessWidget {
  const _ProofMessage({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedImageNotFound01,
              size: 48,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SacPressable(
                listenOnly: true,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: onRetry,
                  child: Text('certificate_import.viewer.retry'.tr()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
