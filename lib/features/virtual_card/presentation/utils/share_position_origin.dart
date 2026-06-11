import 'package:flutter/material.dart';

/// Returns a valid non-zero global rect for iOS/iPad share popovers.
Rect? sharePositionOriginForContext(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }

  final size = renderObject.size;
  if (size.isEmpty) {
    return null;
  }

  return renderObject.localToGlobal(Offset.zero) & size;
}
