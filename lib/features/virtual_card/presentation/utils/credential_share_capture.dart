import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef RepaintBoundaryPngEncoder = Future<Uint8List> Function(
  RenderRepaintBoundary boundary,
  double pixelRatio,
);

/// Captures a [RepaintBoundary] as PNG bytes after Flutter has had a chance to
/// paint any state changes scheduled by the tap handler.
Future<Uint8List> captureCredentialBoundaryPng({
  required GlobalKey boundaryKey,
  required BuildContext viewContext,
  double? pixelRatio,
  RepaintBoundaryPngEncoder encoder = _encodeBoundaryAsPng,
}) async {
  final effectivePixelRatio = pixelRatio ??
      View.of(viewContext).devicePixelRatio.clamp(2.0, 3.0).toDouble();

  await _waitForNextFrame();

  final boundary = boundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) {
    throw StateError('Credential boundary is not available for capture');
  }

  if (boundary.debugNeedsPaint) {
    await _waitForNextFrame();
  }

  return encoder(boundary, effectivePixelRatio);
}

Future<Uint8List> _encodeBoundaryAsPng(
  RenderRepaintBoundary boundary,
  double pixelRatio,
) async {
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  if (byteData == null) {
    throw StateError('Credential image could not be encoded');
  }

  return byteData.buffer.asUint8List();
}

Future<void> _waitForNextFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  WidgetsBinding.instance.ensureVisualUpdate();
  return completer.future;
}
