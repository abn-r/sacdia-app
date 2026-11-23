import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';

/// Free text inside a group (the rejection reason), left aligned and full
/// width.
class ServiceCredentialTextRow extends StatelessWidget {
  const ServiceCredentialTextRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontSize: SacFontSize.titleMedium,
          height: 1.4,
          color: context.sac.text,
        ),
      ),
    );
  }
}
