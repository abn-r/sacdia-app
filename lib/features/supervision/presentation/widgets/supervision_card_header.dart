import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/relative_time.dart';

/// First line of a queue card: its title and, at the end, how long ago the
/// item arrived or was decided.
///
/// The time never takes more than part of the line, so a long relative time
/// (large text, another language) shortens instead of pushing the title out.
class SupervisionCardHeader extends StatelessWidget {
  const SupervisionCardHeader({super.key, required this.title, this.when});

  final String title;
  final DateTime? when;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SacFontSize.titleMedium,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
          if (when != null) ...[
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.45,
              ),
              child: Text(
                formatRelativeTime(when),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  height: 1.5,
                  color: c.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
