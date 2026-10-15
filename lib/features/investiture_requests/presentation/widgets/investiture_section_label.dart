import 'package:flutter/material.dart';

import '../../../../core/theme/sac_colors.dart';

/// Título de bloque de las listas de investidura, con contador opcional.
class InvestitureSectionLabel extends StatelessWidget {
  const InvestitureSectionLabel({
    super.key,
    required this.title,
    this.count,
  });

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.ink900,
                  ),
            ),
          ),
          if (count != null)
            Text(
              '$count',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.ink500,
                  ),
            ),
        ],
      ),
    );
  }
}
