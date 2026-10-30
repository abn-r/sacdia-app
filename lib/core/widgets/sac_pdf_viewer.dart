import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

/// A full-screen PDF viewer that accepts either a local file path or a public
/// remote URL.
///
/// - Local path (starts with '/'): displayed directly without any network request.
/// - Remote URL (http/https): downloaded using a plain Dio instance.
///   These should be publicly accessible URLs (e.g. Cloudflare R2 signed URLs)
///   that do NOT require authentication headers.
///
/// IMPORTANT: Never pass backend URLs that require a Bearer token to this
/// widget. Authenticated PDFs must be downloaded by the data source layer
/// (using the injected authenticated Dio client) and the resulting local path
/// must be passed here instead.
class SacPdfViewer extends StatefulWidget {
  /// Either a local absolute file path or a public http/https URL.
  final String pdfSource;
  final String? title;

  /// One page per view with a "Page X of N" bar and previous/next buttons.
  final bool horizontalPaged;

  /// First page to show, 1-based. Out of range (below 1 or above
  /// [pageCount]) falls back to page 1.
  final int initialPage;

  /// Known page total. When null the total comes from the PDF render.
  final int? pageCount;

  /// Shows the save/share action. Disable it for sealed documents.
  final bool allowShare;

  /// White-on-black chrome (full-screen proof viewing).
  final bool dark;

  /// Extra top bar actions, after the share action.
  final List<Widget> actions;

  /// Replaces the built-in error state, so the caller can offer its own retry.
  final WidgetBuilder? errorBuilder;

  const SacPdfViewer({
    super.key,
    required this.pdfSource,
    this.title,
    this.horizontalPaged = false,
    this.initialPage = 1,
    this.pageCount,
    this.allowShare = true,
    this.dark = false,
    this.actions = const [],
    this.errorBuilder,
  });

  static void show(
    BuildContext context, {
    required String pdfSource,
    String? title,
  }) {
    Navigator.of(context).push(
      SacFadeThroughRoute(
        builder: (_) => SacPdfViewer(pdfSource: pdfSource, title: title),
      ),
    );
  }

  @override
  State<SacPdfViewer> createState() => _SacPdfViewerState();
}

class _SacPdfViewerState extends State<SacPdfViewer> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  String? _fileName;
  final GlobalKey _saveButtonKey = GlobalKey();
  bool _isSharing = false;
  late int _currentPage;
  int _totalPages = 0;
  PDFViewController? _controller;

  int get _total => _totalPages > 0 ? _totalPages : (widget.pageCount ?? 0);

  /// Tracks whether this widget created the temp file (so we own cleanup).
  bool _ownsTempFile = false;

  bool get _isLocalPath => widget.pdfSource.startsWith('/');

  @override
  void initState() {
    super.initState();
    final count = widget.pageCount;
    final valid = widget.initialPage >= 1 &&
        (count == null || widget.initialPage <= count);
    _currentPage = valid ? widget.initialPage - 1 : 0;
    if (_isLocalPath) {
      _useLocalFile();
    } else {
      _downloadPdf();
    }
  }

  @override
  void dispose() {
    _deleteTempFile();
    super.dispose();
  }

  /// Uses the already-local file directly — no download needed.
  void _useLocalFile() {
    final file = File(widget.pdfSource);
    if (file.existsSync()) {
      setState(() {
        _localPath = widget.pdfSource;
        _fileName = _safePdfFileNameFromSource(widget.pdfSource);
        _loading = false;
      });
    } else {
      setState(() {
        _error = tr('core.pdf_viewer.error_not_found');
        _loading = false;
      });
    }
  }

  /// Downloads a publicly accessible PDF URL (no auth required).
  /// Use only for public signed URLs such as Cloudflare R2 pre-signed links.
  Future<void> _downloadPdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final filename = _safePdfFileNameFromSource(
        widget.pdfSource,
        fallback: 'sacdia_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      final filePath = '${dir.path}/$filename';

      // Plain Dio is intentional here: this path is only reached for public
      // signed URLs that do not require an Authorization header.
      await Dio().download(widget.pdfSource, filePath);

      if (mounted) {
        _ownsTempFile = true;
        setState(() {
          _localPath = filePath;
          _fileName = filename;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = tr('core.pdf_viewer.error_download');
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteTempFile() async {
    if (!_ownsTempFile) return;
    final path = _localPath;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Cleanup failure is non-fatal — temp files are evicted by the OS anyway.
    }
  }

  Future<void> _sharePdf() async {
    final localPath = _localPath;
    if (_isSharing || localPath == null) return;

    setState(() => _isSharing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile(
            localPath,
            name: _fileName ?? _safePdfFileNameFromSource(widget.pdfSource),
            mimeType: 'application/pdf',
          ),
        ],
        sharePositionOrigin: _sharePositionOriginForContext(
          _saveButtonKey.currentContext ?? context,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      SacSnackBar.showMessenger(
          messenger, tr('core.pdf_viewer.error_download'));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title?.trim();
    final pageLabel = _total > 0 ? _pageLabel() : null;
    final fg = widget.dark ? Colors.white : null;

    final scaffold = Scaffold(
      backgroundColor: widget.dark ? Colors.black : Colors.white,
      appBar: SacTopBar(
        title: (title != null && title.isNotEmpty) ? title : (pageLabel ?? ''),
        subtitle: (title != null && title.isNotEmpty) ? pageLabel : null,
        backgroundColor: widget.dark ? Colors.black : null,
        foregroundColor: fg,
        leading: SacPressable(
          listenOnly: true,
          child: IconButton(
            enableFeedback: false,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: fg),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          if (widget.allowShare)
            SacPressable(
              listenOnly: true,
              child: IconButton(
                enableFeedback: false,
                key: _saveButtonKey,
                tooltip: 'common.save'.tr(),
                onPressed: _localPath == null || _loading || _isSharing
                    ? null
                    : _sharePdf,
                icon: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : HugeIcon(
                        icon: HugeIcons.strokeRoundedDownload01, color: fg),
              ),
            ),
          ...widget.actions,
        ],
      ),
      body: _buildBody(),
    );
    if (!widget.dark) return scaffold;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: scaffold,
    );
  }

  String _pageLabel() => tr(
        'core.pdf_viewer.page_indicator',
        namedArgs: {'current': '${_currentPage + 1}', 'total': '$_total'},
      );

  void _goToPage(int page) {
    _controller?.setPage(page);
    setState(() => _currentPage = page);
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SacLoading(color: widget.dark ? Colors.white : null),
            const SizedBox(height: 12),
            Text(
              'core.pdf_viewer.downloading'.tr(),
              style: TextStyle(color: widget.dark ? Colors.white : null),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      final custom = widget.errorBuilder;
      if (custom != null) return custom(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 48,
                color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            SacPressable(
              listenOnly: true,
              child: TextButton(
                style: const ButtonStyle(enableFeedback: false),
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  if (_isLocalPath) {
                    _useLocalFile();
                  } else {
                    _downloadPdf();
                  }
                },
                child: Text(tr('core.pdf_viewer.retry')),
              ),
            ),
          ],
        ),
      );
    }

    final paged = widget.horizontalPaged;
    final pdf = PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: paged,
      pageSnap: paged,
      autoSpacing: !paged,
      pageFling: true,
      defaultPage: _currentPage,
      onViewCreated: (controller) => _controller = controller,
      onRender: (pages) {
        if (mounted) setState(() => _totalPages = pages ?? 0);
      },
      onPageChanged: (page, total) {
        if (mounted) setState(() => _currentPage = page ?? 0);
      },
      onError: (error) {
        if (mounted) setState(() => _error = tr('core.pdf_viewer.error_open'));
      },
    );
    if (!paged || _total < 2) return pdf;
    return Column(children: [Expanded(child: pdf), _buildPageBar()]);
  }

  /// "Page X of N" with previous/next buttons (the accessible alternative to
  /// swiping) and a dot indicator.
  Widget _buildPageBar() {
    final fg = widget.dark ? Colors.white : Colors.black87;
    final animate = !SacMotion.reduceMotionOf(context);
    // The tooltip is also the accessible label; no outer Semantics so the
    // button keeps its own tap action for screen readers.
    Widget arrow(HugeIconData icon, String label, int? target) => SacPressable(
          listenOnly: true,
          child: IconButton(
            enableFeedback: false,
            tooltip: label,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            onPressed: target == null ? null : () => _goToPage(target),
            icon: HugeIcon(
              icon: icon,
              color: target == null ? fg.withValues(alpha: 0.3) : fg,
            ),
          ),
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                arrow(
                  HugeIcons.strokeRoundedArrowLeft01,
                  'core.pdf_viewer.previous_page'.tr(),
                  _currentPage > 0 ? _currentPage - 1 : null,
                ),
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(_pageLabel(), style: TextStyle(color: fg)),
                  ),
                ),
                arrow(
                  HugeIcons.strokeRoundedArrowRight01,
                  'core.pdf_viewer.next_page'.tr(),
                  _currentPage < _total - 1 ? _currentPage + 1 : null,
                ),
              ],
            ),
            if (_total <= 10)
              ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_total, (i) {
                    final selected = i == _currentPage;
                    return AnimatedContainer(
                      duration: animate ? SacMotion.switcher : Duration.zero,
                      curve: SacMotion.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: selected ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: selected ? fg : fg.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Rect? _sharePositionOriginForContext(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  final size = renderObject.size;
  if (size.isEmpty) return null;
  return renderObject.localToGlobal(Offset.zero) & size;
}

String? _lastNonEmptySegment(List<String>? segments) {
  if (segments == null) return null;
  for (final segment in segments.reversed) {
    if (segment.trim().isNotEmpty) return segment;
  }
  return null;
}

String _safePdfFileNameFromSource(String source, {String? fallback}) {
  final fallbackName = fallback ??
      'sacdia_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final uri = Uri.tryParse(source);
  final rawSegment = _lastNonEmptySegment(uri?.pathSegments);
  final decoded =
      rawSegment == null ? fallbackName : Uri.decodeComponent(rawSegment);
  var sanitized = decoded.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (sanitized.isEmpty) sanitized = fallbackName;
  if (!sanitized.toLowerCase().endsWith('.pdf')) sanitized = '$sanitized.pdf';
  return sanitized;
}
