import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';

/// Square tile with the certificate icon, tinted with the accent. The same
/// tile marks a certification in Mis clases, the catalog and the header.
class CertificationIconTile extends StatelessWidget {
  const CertificationIconTile({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context).color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: ExcludeSemantics(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCertificate01,
          size: size * 0.55,
          color: accent,
        ),
      ),
    );
  }
}

/// Icon, full name and status of a certification: the top of its screen.
class CertificationHeader extends StatelessWidget {
  const CertificationHeader({
    super.key,
    required this.name,
    this.status,
  });

  final String name;

  /// Already translated; «Disponible», «En curso · 2026», «Certificada · 2025».
  final String? status;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final status = this.status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Semantics(
        container: true,
        header: true,
        excludeSemantics: true,
        label: [name, if (status != null) status].join('. '),
        child: Row(
          children: [
            const CertificationIconTile(size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.headlineMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: c.text,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
