import 'package:flutter/material.dart';

import '../animations/page_transitions.dart';
import '../widgets/sac_image_viewer.dart';
import '../widgets/sac_pdf_viewer.dart';
import 'consent_evidence.dart';

/// Abre la ficha firmada en pantalla completa.
///
/// La URL es firmada y caduca: las imágenes se pintan sin caché en disco
/// (`cacheNetwork: false`) y se desactiva guardar/compartir, que no tiene
/// sentido en un documento legal de un menor.
Future<void> openConsentEvidence(
  BuildContext context,
  ConsentEvidenceAccess evidence, {
  String? title,
}) {
  final route = SacFadeThroughRoute<void>(
    builder: (_) => evidence.isPdf
        ? SacPdfViewer(
            pdfSource: evidence.url,
            title: title,
            allowShare: false,
          )
        : SacImageViewer(
            imageUrl: evidence.url,
            title: title,
            allowShare: false,
            cacheNetwork: false,
          ),
  );
  return Navigator.of(context).push<void>(route);
}
