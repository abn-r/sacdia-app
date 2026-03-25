import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

class SacPdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String? title;

  const SacPdfViewer({
    super.key,
    required this.pdfUrl,
    this.title,
  });

  static void show(BuildContext context, {required String pdfUrl, String? title}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SacPdfViewer(pdfUrl: pdfUrl, title: title),
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

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final filename = 'sacdia_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$filename';

      await Dio().download(widget.pdfUrl, filePath);

      if (mounted) {
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                _downloadPdf();
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
