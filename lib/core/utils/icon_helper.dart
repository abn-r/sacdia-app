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

/// Builds a HugeIcons widget from a [HugeIconData] constant.
///
/// SACDIA UI standardizes on `HugeIcons.strokeRoundedXxx` constants.
Widget buildIcon(HugeIconData icon, {double size = 24, Color? color}) {
  return HugeIcon(icon: icon, size: size, color: color ?? Colors.black);
}
