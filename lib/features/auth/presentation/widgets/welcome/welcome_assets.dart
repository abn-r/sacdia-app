import 'package:flutter/material.dart';

/// Honors 7 and 11 ship as animated GIFs; the rest are PNG.
const Set<int> _gifHonors = {7, 11};

String welcomeHonorAsset(int number) =>
    'assets/img/welcome/honor-$number.${_gifHonors.contains(number) ? 'gif' : 'png'}';

String welcomeClassAsset(String code) => 'assets/img/logos-clases/$code.png';

Widget _decoded(BuildContext context, String asset, double size) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    cacheWidth: (size * dpr).round(),
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}

/// Class badge image (`AV-01`, `CQ-05`, `GM-01`...) at [size].
Widget welcomeClassBadge(String code, double size) => Builder(
      builder: (context) => _decoded(context, welcomeClassAsset(code), size),
    );

/// Honor image `honor-N` at [size].
Widget welcomeHonor(int number, double size) => Builder(
      builder: (context) => _decoded(context, welcomeHonorAsset(number), size),
    );
