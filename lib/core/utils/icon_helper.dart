import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Builds an icon widget from either [IconData] or HugeIcons data.
///
/// Supports both `Icons.xxx` (Material) and `HugeIcons.strokeRoundedXxx`.
Widget buildIcon(dynamic icon, {double size = 24, Color? color}) {
  if (icon is IconData) {
    return Icon(icon, size: size, color: color);
  }
  return HugeIcon(icon: icon, size: size, color: color ?? Colors.black);
}
