import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

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

  const SacPdfViewer({
    super.key,
    required this.pdfSource,
    this.title,
  });

  static void show(
    BuildContext context, {
    required String pdfSource,
    String? title,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
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
  int _currentPage = 0;
  int _totalPages = 0;

  /// Tracks whether this widget created the temp file (so we own cleanup).
  bool _ownsTempFile = false;

  bool get _isLocalPath => widget.pdfSource.startsWith('/');

  @override
  void initState() {
    super.initState();
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
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'El archivo PDF no se encontró en el dispositivo';
        _loading = false;
      });
    }
  }

  /// Downloads a publicly accessible PDF URL (no auth required).
  /// Use only for public signed URLs such as Cloudflare R2 pre-signed links.
  Future<void> _downloadPdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final filename =
          'sacdia_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$filename';

      // Plain Dio is intentional here: this path is only reached for public
      // signed URLs that do not require an Authorization header.
      await Dio().download(widget.pdfSource, filePath);

      if (mounted) {
        _ownsTempFile = true;
        setState(() {
          _localPath = filePath;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo descargar el PDF';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null)
              Text(
                widget.title!,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            if (_totalPages > 0)
              Text(
                'Pagina ${_currentPage + 1} de $_totalPages',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Descargando PDF...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            TextButton(
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
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onRender: (pages) {
        if (mounted) setState(() => _totalPages = pages ?? 0);
      },
      onPageChanged: (page, total) {
        if (mounted) setState(() => _currentPage = page ?? 0);
      },
      onError: (error) {
        if (mounted) setState(() => _error = 'Error al abrir el PDF');
      },
    );
  }
}
