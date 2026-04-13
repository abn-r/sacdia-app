import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// The type of a HugeIcons icon constant.
///
/// All icons in [HugeIcons] are `List<List<dynamic>>`. Using this typedef
/// instead of writing the full nested list type avoids recurring type errors
/// when declaring widget properties that accept a HugeIcons icon.
///
/// Usage:
/// ```dart
/// import 'package:sacdia_app/core/utils/icon_helper.dart';
///
/// class _MyWidget extends StatelessWidget {
///   final HugeIconData icon;
///   ...
/// }
/// ```
typedef HugeIconData = List<List<dynamic>>;

/// Builds an icon widget from either [IconData] or [HugeIconData].
///
/// Supports both `Icons.xxx` (Material) and `HugeIcons.strokeRoundedXxx`.
/// Use this in generic widgets that need to accept either icon system.
/// For widgets that exclusively use HugeIcons, declare the field as
/// [HugeIconData] and use [HugeIcon] directly.
Widget buildIcon(dynamic icon, {double size = 24, Color? color}) {
  if (icon is IconData) {
    return Icon(icon, size: size, color: color);
  }
  return HugeIcon(icon: icon, size: size, color: color ?? Colors.black);
}
