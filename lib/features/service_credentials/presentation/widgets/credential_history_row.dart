import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../domain/entities/service_credential.dart';
import '../utils/service_credential_labels.dart';
import '../utils/service_credential_status_style.dart';

/// An older credential in «Historial»: status icon, the course and
/// «{status} · {date}». Not interactive: own credentials have nothing to open.
class CredentialHistoryRow extends StatelessWidget {
  const CredentialHistoryRow({super.key, required this.credential});

  final ServiceCredential credential;

  @override
  Widget build(BuildContext context) {
    final style = serviceCredentialStatusStyle(context, credential.status);
    final date =
        credential.reviewedAt ?? credential.createdAt ?? credential.completedAt;
    final detail = [
      style.label,
      if (date != null) serviceCredentialDate(context, date),
    ].join(' · ');
    return SacListRow(
      leading: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.container,
          shape: BoxShape.circle,
        ),
        child: ExcludeSemantics(
          child: HugeIcon(
            icon: style.icon,
            size: 17,
            color: style.onContainer,
          ),
        ),
      ),
      title: serviceCredentialTitle(),
      subtitle: detail,
      subtitleColor: context.sac.textSecondary,
    );
  }
}
